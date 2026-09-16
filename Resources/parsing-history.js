"use strict";

const daySelect = document.querySelector("#day");
const search = document.querySelector("#search");
const status = document.querySelector("#status");
const entries = document.querySelector("#entries");
const more = document.querySelector("#more");
const refresh = document.querySelector("#refresh");
let token = location.hash.slice(1);
try {
  if (token) sessionStorage.setItem("moepeek-review-token", token);
  else token = sessionStorage.getItem("moepeek-review-token") || "";
} catch { /* 禁用浏览器存储时，本次页面仍使用内存令牌。 */ }
history.replaceState(null, "", location.pathname);
let records = [];
let skipped = 0;
let visibleCount = 30;
let generation = 0;
let controller;

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

async function request(path, signal) {
  const response = await fetch(path, { headers: { Authorization: `Bearer ${token}` }, cache: "no-store", signal });
  if (response.status === 403) throw new Error("访问已过期，请从 MoePeek 的「英语复习」重新打开页面。");
  if (!response.ok) throw new Error("暂时无法读取记录（文件可能被占用或过大），请稍后刷新。原文件未被修改。");
  return response;
}

function validTerms(terms, key) {
  return Array.isArray(terms) && terms.every(term => typeof term?.[key] === "string" && typeof term.note === "string");
}

function validRecord(entry) {
  const result = entry?.result;
  if (typeof entry?.sourceText !== "string" || typeof entry.providerName !== "string"
    || typeof entry.completedAt !== "string" || !result) return false;
  // 旧记录仅在读取时展示原字段，不迁移或改写源文件。
  if (entry.schemaVersion === 1) {
    return typeof result.correctedText === "string"
      && (result.naturalExpression == null || typeof result.naturalExpression === "string")
      && (result.notice == null || typeof result.notice === "string")
      && validTerms(result.words, "word") && validTerms(result.grammar, "structure");
  }
  if (entry.schemaVersion !== 2) return false;
  switch (result.mode) {
    case "check":
      return Array.isArray(result.items) && result.items.every(item => typeof item?.wrong === "string"
        && typeof item.right === "string" && typeof item.reason === "string")
        && (result.rephrase == null || typeof result.rephrase === "string");
    case "tutor":
      return typeof result.sentence === "string" && validTerms(result.words, "word") && validTerms(result.grammar, "structure");
    case "skip": return true;
    default: return false;
  }
}

function resultSearchParts(entry) {
  const result = entry.result;
  if (entry.schemaVersion === 1) {
    return [result.correctedText, result.naturalExpression, result.notice,
      ...result.words.flatMap(word => [word.word, word.note]), ...result.grammar.flatMap(item => [item.structure, item.note])];
  }
  switch (result.mode) {
    case "check": return [result.rephrase, ...result.items.flatMap(item => [item.wrong, item.right, item.reason])];
    case "tutor": return [result.sentence, ...result.words.flatMap(word => [word.word, word.note]),
      ...result.grammar.flatMap(item => [item.structure, item.note])];
    default: return ["跳过"];
  }
}

function addSection(parent, title, text, className = "note") {
  if (!text) return;
  parent.append(element("h3", title), element("p", text, className));
}

function addTerms(parent, title, terms, key) {
  if (!terms.length) return;
  parent.append(element("h3", title));
  const list = element("dl");
  for (const term of terms) {
    const row = element("div", undefined, "term");
    row.append(element("dt", term[key]), element("dd", term.note));
    list.append(row);
  }
  parent.append(list);
}

function card(entry, index) {
  const article = element("article", undefined, "card");
  const time = new Date(entry.completedAt);
  const model = typeof entry.model === "string" && entry.model ? ` · ${entry.model}` : "";
  article.append(element("p", `${String(index + 1).padStart(2, "0")} · ${Number.isNaN(time.getTime()) ? "" : time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })} · ${entry.providerName}${model}`, "meta"));
  article.append(element("h2", entry.sourceText, "source"));
  const detail = element("details");
  detail.append(element("summary", "展开解析 · 对照自己的理解"));
  const result = entry.result;
  if (entry.schemaVersion === 1) {
    addSection(detail, "英文正文", result.correctedText, "expression");
    addSection(detail, "更自然的表达", result.naturalExpression, "expression");
    addSection(detail, "学习提示", result.notice);
    addTerms(detail, "词汇与短语", result.words, "word");
    addTerms(detail, "句子结构与语法", result.grammar, "structure");
  } else if (result.mode === "check") {
    addSection(detail, "英文检查", result.items.length || result.rephrase ? "纠错与建议" : "表达自然，无需修改。");
    for (const item of result.items) addSection(detail, `${item.wrong} → ${item.right}`, item.reason || "纠正表达");
    addSection(detail, "建议改写", result.rephrase, "expression");
  } else if (result.mode === "tutor") {
    addSection(detail, "英文正文", result.sentence, "expression");
    addTerms(detail, "词汇与短语", result.words, "word");
    addTerms(detail, "句子结构与语法", result.grammar, "structure");
  } else {
    addSection(detail, "已跳过", "内容过短、代码较多或不适合语言分析。");
  }
  article.append(detail);
  return article;
}

function render() {
  const query = search.value.trim().toLocaleLowerCase();
  const filtered = records.filter(entry => entry.searchText.includes(query));
  entries.replaceChildren(...filtered.slice(0, visibleCount).map((entry, index) => card(entry.record, index)));
  more.hidden = filtered.length <= visibleCount;
  const warning = skipped ? ` ${skipped} 条损坏或版本不支持的记录未显示，原文件已保留。` : "";
  status.textContent = (filtered.length ? `${filtered.length} 条学习笔记${query ? " · 当天搜索结果" : " · 先回想，再展开"}`
    : records.length ? "没有匹配的笔记，试试其他关键词。" : "这一天还没有学习笔记。") + warning;
}

async function load(reloadDays = false) {
  const current = ++generation;
  controller?.abort();
  controller = new AbortController();
  const signal = controller.signal;
  entries.replaceChildren();
  more.hidden = true;
  records = [];
  skipped = 0;
  search.disabled = true;
  refresh.disabled = true;
  status.textContent = "正在读取学习笔记…";
  try {
    if (!token) throw new Error("请从 MoePeek 菜单中的「英语复习」打开此页。");
    if (reloadDays) {
      const days = await (await request("/api/days", signal)).json();
      if (current !== generation) return;
      if (!Array.isArray(days) || !days.every(day => typeof day === "string" && /^\d{4}-\d{2}-\d{2}$/.test(day))) {
        throw new Error("日期目录格式不正确，请重新打开页面。");
      }
      const previous = daySelect.value;
      daySelect.replaceChildren(...days.map(day => { const option = element("option", day); option.value = day; return option; }));
      daySelect.disabled = !days.length;
      if (days.includes(previous)) daySelect.value = previous;
      if (!days.length) {
        status.textContent = "还没有学习笔记。在 MoePeek 完成一次解析后，点击「刷新记录」。";
        return;
      }
    }
    const text = await (await request(`/api/history/${daySelect.value}`, signal)).text();
    if (current !== generation) return;
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      try {
        const record = JSON.parse(line);
        if (!validRecord(record)) { skipped++; continue; }
        const searchText = [record.sourceText, ...resultSearchParts(record)]
          .filter(Boolean).join("\n").toLocaleLowerCase();
        records.push({ record, searchText });
      } catch { skipped++; }
    }
    records.reverse();
    visibleCount = 30;
    render();
  } catch (error) {
    if (current !== generation || error.name === "AbortError") return;
    status.textContent = error instanceof TypeError ? "无法连接 MoePeek。请保持应用运行，并从菜单重新打开「英语复习」。" : error.message;
  } finally {
    if (current === generation) { search.disabled = false; refresh.disabled = false; }
  }
}

document.querySelector("form").addEventListener("submit", event => event.preventDefault());
daySelect.addEventListener("change", () => load());
refresh.addEventListener("click", () => load(true));
search.addEventListener("input", () => { visibleCount = 30; render(); });
more.addEventListener("click", () => { visibleCount += 30; render(); });
load(true);

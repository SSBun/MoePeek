"use strict";

const daySelect = document.querySelector("#day");
const dates = document.querySelector("#dates");
const search = document.querySelector("#search");
const status = document.querySelector("#status");
const entries = document.querySelector("#entries");
const more = document.querySelector("#more");
const refresh = document.querySelector("#refresh");
const theme = document.querySelector("#theme");
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
let reviewSnapshot;
let reviewVersion = 0;
let reviewBusy = false;
let reviewControls = [];

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

async function request(path, signal, method = "GET") {
  const response = await fetch(path, { method, headers: { Authorization: `Bearer ${token}` }, cache: "no-store", signal });
  if (response.status === 403) throw new Error("访问已过期，请从 MoePeek 的「英语复习」重新打开页面。");
  if (!response.ok) throw new Error("暂时无法读取或保存记录，请稍后刷新重试。原解析记录未被修改。");
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

function hasReviewContent(entry) {
  // 只过滤明确的无修改 check，不根据旧版讲解文本猜测记录含义。
  return entry.schemaVersion !== 2 || entry.result.mode !== "check"
    || entry.result.items.length > 0 || Boolean(entry.result.rephrase?.trim());
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
    default: return ["内容过短、代码较多或不适合语言分析。", "跳过"];
  }
}

function resultHeader(mode) {
  const heading = element("h3", undefined, "result-title");
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 20 20");
  svg.setAttribute("fill", "none");
  svg.setAttribute("stroke", "currentColor");
  svg.setAttribute("stroke-width", "1.5");
  svg.setAttribute("stroke-linecap", "round");
  svg.setAttribute("stroke-linejoin", "round");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(svg.namespaceURI, "path");
  path.setAttribute("d", {
    check: "M12 4l4 4M4 12l-1 5 5-1L17 7a2.8 2.8 0 0 0-4-4L4 12M11 17h6",
    tutor: "M5 2h11v14H5a2 2 0 0 0 0 4h12M5 2a2 2 0 0 0-2 2v14M7 2v14M9 12l2-7 2 7m-3.5-2h3",
    skip: "M3 5l7 5-7 5V5ZM10 5l7 5-7 5V5Z",
  }[mode]);
  svg.append(path);
  heading.append(svg, element("span", { check: "Writing check", tutor: "Writing tutor", skip: "MoePeek" }[mode]));
  return heading;
}

function addSentence(parent, text) {
  if (text) parent.append(element("p", "◇ " + text, "sentence"));
}

function addTerms(parent, title, terms, key) {
  if (!terms.length) return;
  parent.append(element("p", title));
  for (const term of terms) {
    const line = element("p");
    line.append(element("span", term[key], "term"), document.createTextNode("  " + term.note));
    parent.append(line);
  }
}

function updateReviewControls() {
  for (const update of reviewControls) update();
}

async function refreshReview() {
  if (!daySelect.value || reviewBusy || !records.length) return;
  const version = ++reviewVersion;
  const day = daySelect.value;
  try {
    const snapshot = await (await request(`/api/review/${day}`)).json();
    if (version !== reviewVersion) return;
    reviewSnapshot = snapshot;
    updateReviewControls();
  } catch (error) {
    if (version !== reviewVersion) return;
    reviewSnapshot = undefined;
    updateReviewControls();
    status.textContent = `无法读取收藏与学习状态：${error.message}`;
  }
}

function cardActions(entry) {
  const actions = element("div", undefined, "card-actions");
  actions.setAttribute("role", "group");
  actions.setAttribute("aria-label", "收藏与学习");
  const favorite = element("button");
  const study = element("button");
  favorite.type = study.type = "button";
  const feedback = element("p", undefined, "action-feedback");
  feedback.setAttribute("role", "status");
  const key = typeof entry.id === "string" ? entry.id.toLowerCase() : "";
  const hasID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(key);
  const day = daySelect.value;
  function update() {
    const state = reviewSnapshot?.states[key];
    const events = state?.studyEvents || [];
    const studied = events.some(event => event.day === reviewSnapshot?.today);
    const favoriteLabel = state?.isFavorite ? "取消收藏" : "收藏";
    favorite.textContent = state?.isFavorite ? "★" : "☆";
    favorite.title = favoriteLabel;
    favorite.setAttribute("aria-label", favoriteLabel);
    favorite.setAttribute("aria-pressed", String(Boolean(state?.isFavorite)));
    const studyLabel = studied ? "今天已学习" : "今天学过了";
    study.textContent = "✓";
    study.classList.toggle("is-studied", studied);
    study.setAttribute("aria-label", studyLabel);
    favorite.disabled = reviewBusy || !reviewSnapshot || !hasID;
    study.disabled = favorite.disabled || studied;
    const last = events.at(-1);
    const progress = !hasID ? "此旧记录缺少有效标识，无法保存状态。"
      : !reviewSnapshot ? "收藏与学习状态暂不可用"
      : `已学习 ${events.length} 次${last ? ` · 最近：${new Date(last.studiedAt).toLocaleString()}` : ""}`;
    study.title = [studyLabel, progress, ...events.map(event => new Date(event.studiedAt).toLocaleString())].join("\n");
  }
  async function save(action) {
    if (reviewBusy || day !== daySelect.value) return;
    reviewBusy = true;
    const version = ++reviewVersion;
    feedback.textContent = "正在保存…";
    updateReviewControls();
    try {
      const snapshot = await (await request(`/api/review/${day}/${key}/${action}`, undefined, "POST")).json();
      if (version !== reviewVersion) return;
      reviewSnapshot = snapshot;
      feedback.textContent = "";
    } catch (error) {
      if (version !== reviewVersion) return;
      feedback.textContent = `保存未确认，请刷新后重试：${error.message}`;
    } finally {
      reviewBusy = false;
      updateReviewControls();
      if (version !== reviewVersion) refreshReview();
    }
  }
  favorite.addEventListener("click", () => save(reviewSnapshot?.states[key]?.isFavorite ? "unfavorite" : "favorite"));
  study.addEventListener("click", () => save("study"));
  reviewControls.push(update);
  update();
  actions.append(favorite, study, feedback);
  return actions;
}

function card(entry) {
  const article = element("article", undefined, "entry");
  const time = new Date(entry.completedAt);
  const model = typeof entry.model === "string" && entry.model ? ` · ${entry.model}` : "";
  const timestamp = Number.isNaN(time.getTime()) ? "" : time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  article.append(element("p", `${timestamp} · ${entry.providerName}${model}`, "meta"));
  const body = element("div", undefined, "card");
  body.append(element("h2", entry.sourceText, "source"));
  const result = entry.result;
  if (entry.schemaVersion === 1) {
    body.append(resultHeader(result.correctedText || result.naturalExpression ? "tutor" : "skip"));
    addSentence(body, result.correctedText);
    if (result.notice) body.append(element("p", result.notice));
    if (result.naturalExpression) {
      body.append(element("p", "Natural expression"));
      addSentence(body, result.naturalExpression);
    }
    addTerms(body, "Words", result.words, "word");
    addTerms(body, "Grammar", result.grammar, "structure");
  } else {
    body.append(resultHeader(result.mode));
    if (result.mode === "check") {
      for (const item of result.items) {
        const correction = element("div", undefined, "correction");
        const line = element("p");
        line.append(element("del", item.wrong, "wrong"), document.createTextNode(" → "), element("span", item.right, "right"));
        correction.append(line);
        if (item.reason) correction.append(element("p", item.reason));
        body.append(correction);
      }
      addSentence(body, result.rephrase);
    } else if (result.mode === "tutor") {
      addSentence(body, result.sentence);
      addTerms(body, "Words", result.words, "word");
      addTerms(body, "Grammar", result.grammar, "structure");
    } else {
      body.append(element("p", "内容过短、代码较多或不适合语言分析。"));
    }
  }
  const row = element("div", undefined, "card-row");
  row.append(body, cardActions(entry));
  article.append(row);
  return article;
}

function render() {
  const query = search.value.trim().toLocaleLowerCase();
  const filtered = records.filter(entry => entry.searchText.includes(query));
  reviewControls = [];
  entries.replaceChildren(...filtered.slice(0, visibleCount).map(entry => card(entry.record)));
  more.hidden = filtered.length <= visibleCount;
  const warning = skipped ? ` ${skipped} 条损坏或版本不支持的记录未显示，原文件已保留。` : "";
  status.textContent = (filtered.length ? `${filtered.length} 条解析${query ? " · 当天搜索结果" : ""}`
    : records.length ? "没有匹配的解析，试试其他关键词。" : "这一天没有需要复习的解析。") + warning;
}

function updateSelectedDay() {
  for (const button of dates.querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.day === daySelect.value));
  }
}

function renderDates(days) {
  dates.replaceChildren();
  for (const day of days) {
    const button = element("button", day);
    button.type = "button";
    button.dataset.day = day;
    button.addEventListener("click", () => { daySelect.value = day; load(); });
    dates.append(button);
  }
  if (!days.length) dates.append(element("span", "暂无记录", "local"));
  updateSelectedDay();
}

async function load(reloadDays = false) {
  const current = ++generation;
  ++reviewVersion;
  reviewSnapshot = undefined;
  reviewControls = [];
  controller?.abort();
  controller = new AbortController();
  const signal = controller.signal;
  let loaded = false;
  entries.replaceChildren();
  more.hidden = true;
  records = [];
  skipped = 0;
  search.disabled = true;
  refresh.disabled = true;
  updateSelectedDay();
  status.textContent = "正在读取解析记录…";
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
      renderDates(days);
    }
    if (!daySelect.value) {
      status.textContent = "还没有学习笔记。在 MoePeek 完成一次有学习内容的解析后，点击「刷新记录」。";
      return;
    }
    const text = await (await request(`/api/history/${daySelect.value}`, signal)).text();
    if (current !== generation) return;
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      try {
        const record = JSON.parse(line);
        if (!validRecord(record)) { skipped++; continue; }
        if (!hasReviewContent(record)) continue;
        const searchText = [record.sourceText, ...resultSearchParts(record)]
          .filter(Boolean).join("\n").toLocaleLowerCase();
        records.push({ record, searchText });
      } catch { skipped++; }
    }
    records.reverse();
    visibleCount = 30;
    loaded = true;
    render();
    await refreshReview();
  } catch (error) {
    if (current !== generation || error.name === "AbortError") return;
    status.textContent = error instanceof TypeError ? "无法连接 MoePeek。请保持应用运行，并从菜单重新打开「英语复习」。" : error.message;
  } finally {
    if (current === generation) { search.disabled = !loaded; refresh.disabled = false; }
  }
}

document.querySelector("form").addEventListener("submit", event => event.preventDefault());
daySelect.addEventListener("change", () => load());
refresh.addEventListener("click", () => load(true));
search.addEventListener("input", () => { visibleCount = 30; render(); });
more.addEventListener("click", () => { visibleCount += 30; render(); });
theme.addEventListener("change", () => { document.documentElement.dataset.theme = theme.value; });
document.documentElement.dataset.theme = theme.value;
// 定期和重新聚焦时向本机服务校准日期，跨午夜或多标签页无需重新打开页面。
setInterval(refreshReview, 30_000);
window.addEventListener("focus", refreshReview);
load(true);

"use strict";

// 三个示例共用同一组虚构数据，不读取文件、网络或真实解析历史。
const samples = [
  {
    day: "2026-09-16", time: "10:42",
    source: "I have a good idea that MoePeek can provides a local server.",
    result: {
      mode: "check",
      items: [
        { wrong: "can provides", right: "can provide", reason: "情态动词 can 后接动词原形。" },
      ],
      rephrase: "Here's an idea: MoePeek could provide a local server.",
    },
  },
  {
    day: "2026-09-16", time: "10:36",
    source: "先把内容展示做好，其他功能可以以后再加。",
    result: {
      mode: "tutor",
      sentence: "Let's get the content display right first. We can add other features later.",
      words: [
        { word: "get … right", note: "把某件事做好，强调达到正确或满意的效果。" },
        { word: "later", note: "以后；用于说明不必现在就做。" },
      ],
      grammar: [
        { structure: "Let's + 动词原形", note: "提出共同采取行动的建议。" },
        { structure: "can + 动词原形", note: "表示可以做某事，这里是在提出后续安排。" },
      ],
    },
  },
  {
    day: "2026-09-16", time: "10:21",
    source: "The current layout looks good to me.",
    result: { mode: "check", items: [], rephrase: null },
  },
  {
    day: "2026-09-15", time: "18:05",
    source: "我想让网页和现有面板看起来一样。",
    result: {
      mode: "tutor", sentence: "I'd like the web page to look like the existing panel.",
      words: [
        { word: "look like", note: "看起来像；描述外观上的相似。" },
        { word: "existing", note: "现有的，已经存在的。" },
      ],
      grammar: [{ structure: "would like + 宾语 + to do", note: "礼貌地表达希望某人或某物达到某种状态。" }],
    },
  },
  { day: "2026-09-15", time: "17:52", source: "const count = 3;", result: { mode: "skip" } },
];

const entries = document.querySelector("#entries");
const daySelect = document.querySelector("#day");
const search = document.querySelector("#search");
const theme = document.querySelector("#theme");
const message = document.querySelector("#status");
const days = [...new Set(samples.map(sample => sample.day))];

function text(tag, value, className) {
  const node = document.createElement(tag);
  node.textContent = value;
  if (className) node.className = className;
  return node;
}

function icon(mode) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 20 20");
  svg.setAttribute("fill", "none");
  svg.setAttribute("stroke", "currentColor");
  svg.setAttribute("stroke-width", "1.4");
  svg.setAttribute("stroke-linecap", "round");
  svg.setAttribute("stroke-linejoin", "round");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(svg.namespaceURI, "path");
  path.setAttribute("d", {
    check: "M12 4l4 4M4 12l-1 5 5-1L17 7a2.8 2.8 0 0 0-4-4L4 12M11 17h6",
    tutor: "M10 5C7 3 4 3 2 4v12c3-1 5-1 8 1 3-2 5-2 8-1V4c-2-1-5-1-8 1v12M5 7h2M5 10h2M13 7h2M13 10h2",
    skip: "M3 5l7 5-7 5V5ZM10 5l7 5-7 5V5Z",
  }[mode]);
  svg.append(path);
  return svg;
}

function renderResult(result) {
  const container = document.createElement("div");
  container.className = "result";
  const heading = text("h3", "", "result-title");
  heading.append(icon(result.mode), text("span", { check: "Writing check", tutor: "Writing tutor", skip: "MoePeek" }[result.mode]));
  container.append(heading);
  if (result.mode === "check") {
    if (!result.items.length && !result.rephrase) container.append(text("p", "表达自然，无需修改。", "note"));
    for (const item of result.items) {
      const correction = text("div", "", "correction");
      const line = text("p", "");
      line.append(text("del", item.wrong, "wrong"), text("span", " → ", "note"), text("span", item.right, "right"));
      correction.append(line);
      if (item.reason) correction.append(text("p", item.reason, "note"));
      container.append(correction);
    }
    if (result.rephrase) container.append(text("p", "◇ " + result.rephrase, "sentence"));
  } else if (result.mode === "tutor") {
    container.append(text("p", "◇ " + result.sentence, "sentence"));
    for (const [title, list, key] of [["Words", result.words, "word"], ["Grammar", result.grammar, "structure"]]) {
      if (!list.length) continue;
      container.append(text("p", title, "section-title"));
      for (const item of list) {
        const line = text("p", "");
        line.append(text("span", item[key], "term"), text("span", "  " + item.note, "note"));
        container.append(line);
      }
    }
  } else {
    container.append(text("p", "内容过短、代码较多或不适合语言分析。", "note"));
  }
  return container;
}

function render() {
  const query = search.value.trim().toLocaleLowerCase();
  const records = samples.filter(sample => sample.day === daySelect.value && JSON.stringify(sample).toLocaleLowerCase().includes(query));
  entries.replaceChildren();
  for (const sample of records) {
    const article = document.createElement("article");
    article.className = "entry";
    article.append(text("p", `${sample.day}  ${sample.time}`, "metadata"));
    const panel = text("div", "", "panel");
    panel.append(text("h2", sample.source, "source"), text("hr", "", "divider"), renderResult(sample.result));
    article.append(panel);
    entries.append(article);
  }
  message.textContent = records.length ? `${records.length} 条示例 · 内容默认展开` : "没有匹配的示例。";
  for (const button of document.querySelectorAll("[data-day]")) {
    button.setAttribute("aria-pressed", String(button.dataset.day === daySelect.value));
  }
}

for (const day of days) {
  const option = text("option", day);
  option.value = day;
  daySelect.append(option);
  const button = text("button", day);
  button.type = "button";
  button.dataset.day = day;
  button.addEventListener("click", () => { daySelect.value = day; render(); });
  document.querySelector("#dates").append(button);
}
theme.value = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
document.documentElement.dataset.theme = theme.value;
theme.addEventListener("change", () => { document.documentElement.dataset.theme = theme.value; });
daySelect.addEventListener("change", render);
search.addEventListener("input", render);
document.querySelector("form").addEventListener("submit", event => event.preventDefault());
render();

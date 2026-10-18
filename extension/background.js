// Right-click selected text > "Check with Veritus AI" opens the checker in a small window and runs it.
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({ id: "veritus-check", title: "Check with Veritus AI", contexts: ["selection"] });
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== "veritus-check" || !info.selectionText) return;
  const text = info.selectionText.trim().slice(0, 2000);
  const url = chrome.runtime.getURL("popup.html") + "?auto=1&text=" + encodeURIComponent(text);
  chrome.windows.create({ url, type: "popup", width: 440, height: 700 });
});

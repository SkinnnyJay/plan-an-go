(function () {
  "use strict";

  const viewEl = document.getElementById("view-content");
  const executeBtn = document.getElementById("execute-btn");
  const customArgsEl = document.getElementById("custom-args");
  const outputsEl = document.getElementById("outputs");
  const viewPlanBtn = document.getElementById("view-plan");
  const viewPrdBtn = document.getElementById("view-prd");

  function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  function addOutput(line, type) {
    if (!outputsEl) return;
    const pre = document.createElement("pre");
    pre.className = "output-line " + (type || "stdout");
    pre.textContent = line;
    outputsEl.appendChild(pre);
    outputsEl.scrollTop = outputsEl.scrollHeight;
  }

  function clearOutputs() {
    if (outputsEl) outputsEl.replaceChildren();
  }

  function setViewPlaceholder(id) {
    if (!viewEl) return;
    viewEl.textContent = id === "plan" ? "Load PLAN.md to view milestones and tasks." : "Load PRD.md to view product requirements.";
    viewEl.dataset.mode = id;
  }

  if (viewPlanBtn) {
    viewPlanBtn.addEventListener("click", function () {
      setViewPlaceholder("plan");
    });
  }
  if (viewPrdBtn) {
    viewPrdBtn.addEventListener("click", function () {
      setViewPlaceholder("prd");
    });
  }

  if (executeBtn) {
    executeBtn.addEventListener("click", function () {
      clearOutputs();
      const args = (customArgsEl && customArgsEl.value.trim()) || "";
      addOutput("[system] Execute requested (UI placeholder — use CLI: npm run plan-an-go)", "system");
      if (args) addOutput("[args] " + args, "stdout");
      addOutput("Run: npm run plan-an-go -- " + (args ? args : ""), "stdout");
    });
  }

  setViewPlaceholder("plan");
})();

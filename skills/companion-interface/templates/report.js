document.querySelectorAll("button[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const text = button.getAttribute("data-copy") || "";
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
    window.setTimeout(() => { button.textContent = "Copy"; }, 1200);
  });
});

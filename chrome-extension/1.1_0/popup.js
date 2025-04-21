document.addEventListener('DOMContentLoaded', () => {
    const languageSelect = document.getElementById('languageSelect');
    chrome.storage.sync.get(['selectedLanguage'], (result) => {
        if (result.selectedLanguage) {
            languageSelect.value = result.selectedLanguage;
        }
    });

    languageSelect.addEventListener('change', () => {
        const language = languageSelect.value;
        chrome.storage.sync.set({ selectedLanguage: language });
        setTimeout(() => {
            window.close();
        }, 1000);
    });

    document.getElementById('translateButton').addEventListener('click', () => {
        const language = languageSelect.value;
        chrome.storage.sync.set({ selectedLanguage: language });
        chrome.runtime.sendMessage({ action: 'translatePage', language: language });
        window.close();
    });
});
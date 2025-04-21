chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
        id: 'translatePage',
        title: 'Translate this page',
        contexts: ['all']
    });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
    chrome.storage.sync.get(['selectedLanguage'], (result) => {
        const language = result.selectedLanguage || 'es';
        translatePage(tab, language);
    });
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'translatePage') {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs.length > 0) {
                translatePage(tabs[0], request.language);
            }
        });
        return true;
    } else if (request.action === 'getSelectedLanguage') {
        chrome.storage.sync.get(['selectedLanguage'], (result) => {
            sendResponse({ language: result.selectedLanguage || 'ru' });
        });
        return true;
    }
});

function translatePage(tab, targetLang) {
    const url = `https://translate.google.com/translate?hl=&sl=auto&tl=${targetLang}&u=${encodeURIComponent(tab.url)}`;
    chrome.tabs.update(tab.id, { url: url }, () => {
        chrome.scripting.executeScript({
            target: { tabId: tab.id },
            files: ['adjustTranslate.js']
        });
    });
}


function observeDOMChanges() {
    const observer = new MutationObserver((mutations, observer) => {
        console.log('DOM mutations observed, applying adjustTranslate.js');
        const script = document.createElement('script');
        script.src = chrome.runtime.getURL('adjustTranslate.js');
        document.head.appendChild(script);
        observer.disconnect();
    });

    observer.observe(document, {
        childList: true,
        subtree: true,
        attributes: false,
        characterData: false
    });
}
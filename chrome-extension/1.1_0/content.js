
const icon = document.createElement('div');
const overlay = document.createElement('div');
const tooltip = document.createElement('div');
const closeButton = document.createElement('button');

// Инициализация элементов
(function init() {
    icon.id = 'translate-icon';
    icon.style.position = 'absolute';
    icon.style.background = '#4285F4';
    icon.style.borderRadius = '50%';
    icon.style.width = '36px';
    icon.style.height = '36px';
    icon.style.zIndex = '1000';
    icon.style.cursor = 'pointer';
    icon.style.display = 'none';
    icon.style.backgroundImage = `url(https://www.conveythis.com/wp-content/uploads/2023/07/logo-icon-vertical-white-100x100-1.webp)`;
    icon.style.backgroundSize = 'contain';
    icon.style.backgroundRepeat = 'no-repeat';
    icon.style.backgroundPosition = 'center';
    document.body.appendChild(icon);

    overlay.id = 'translation-overlay';
    overlay.style.position = 'fixed';
    overlay.style.top = '0';
    overlay.style.left = '0';
    overlay.style.width = '100%';
    overlay.style.height = '100%';
    overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.8)';
    overlay.style.backgroundImage = `url(https://www.conveythis.com/wp-content/uploads/2020/09/conveythis-logo-light-1-1.svg)`;
    overlay.style.backgroundSize = '20%';
    overlay.style.backgroundRepeat = 'no-repeat';
    overlay.style.backgroundPositionY = '5%';
    overlay.style.backgroundPositionX = '50%';
    overlay.style.zIndex = '1001';
    overlay.style.display = 'none';
    document.body.appendChild(overlay);

    tooltip.id = 'translation-tooltip';
    tooltip.style.position = 'fixed';
    tooltip.style.backgroundColor = '#fff';
    tooltip.style.border = '2px solid rgb(0 12 137)';
    tooltip.style.padding = '30px';
    tooltip.style.boxShadow = '0px 2px 5px rgba(0, 0, 0, 0.3)';
    tooltip.style.zIndex = '1002';
    tooltip.style.display = 'none';
    tooltip.style.minWidth = '40%';
    tooltip.style.maxWidth = '80%';
    tooltip.style.maxHeight = '80%';
    tooltip.style.overflowY = 'auto';
    tooltip.style.borderRadius = '10px';

    closeButton.className = 'convey-close';
    closeButton.addEventListener('click', () => {
        overlay.style.display = 'none';
        tooltip.style.display = 'none';
    });

    tooltip.appendChild(closeButton);
    document.body.appendChild(tooltip);
})();

document.addEventListener('mouseup', () => {
    const selectedText = getSelectedText();
    console.log('Mouse up event, selected text:', selectedText);

    if (selectedText.length > 0) {
        const range = window.getSelection().getRangeAt(0);
        const rect = range.getBoundingClientRect();
        icon.style.top = `${window.scrollY + rect.bottom + 5}px`;
        icon.style.left = `${window.scrollX + rect.right - 25}px`;
        icon.style.display = 'flex';
        icon.setAttribute('data-selected-text', selectedText);
    } else {
        icon.style.display = 'none';
    }
});

icon.addEventListener('click', async () => {
    const selectedText = icon.getAttribute('data-selected-text');
    const language = await getSelectedLanguage();
    console.log('Icon click event, selected text:', selectedText, 'language:', language);
    if (selectedText && selectedText.length > 0) {
        try {
            const translation = await translateText(selectedText, language);
            console.log('Translation:', translation);
            showTooltip(translation);
        } catch (error) {
            console.error('Error during translation:', error);
        }
    }
});

async function translateText(text, targetLang) {
    const sentences = text.split(/([.!?]\s|\n)/g).filter(Boolean);
    const translationPromises = sentences.map(sentence => translateSentence(sentence.trim(), targetLang));

    const translations = await Promise.all(translationPromises);
    return translations.join('');
}

async function translateSentence(sentence, targetLang) {
    const translateUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${targetLang}&dt=t&q=${encodeURIComponent(sentence)}`;
    try {
        const response = await fetch(translateUrl);
        const data = await response.json();
        return data[0][0][0];
    } catch (error) {
        console.error('Error translating sentence:', error);
        return sentence;
    }
}

function showTooltip(translation) {
    tooltip.innerHTML = translation;
    tooltip.appendChild(closeButton);

    tooltip.style.top = '50%';
    tooltip.style.left = '50%';
    tooltip.style.transform = 'translate(-50%, -50%)';

    overlay.style.display = 'block';
    tooltip.style.display = 'block';

    document.addEventListener('click', (event) => {
        if (!tooltip.contains(event.target) && !icon.contains(event.target)) {
            overlay.style.display = 'none';
            tooltip.style.display = 'none';
        }
    }, { once: true });
}

function getSelectedText() {
    let selectedText = '';
    const selection = window.getSelection();
    if (selection.rangeCount > 0) {
        const range = selection.getRangeAt(0);
        const fragment = range.cloneContents();
        selectedText = fragment.textContent.trim();
    }
    return selectedText;
}

function getSelectedLanguage() {
    return new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({ action: 'getSelectedLanguage' }, (response) => {
            if (chrome.runtime.lastError) {
                reject(chrome.runtime.lastError);
            } else if (response) {
                resolve(response.language || 'ru');
            } else {
                reject(new Error('No response received'));
            }
        });
    });
}
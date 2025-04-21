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

    document.getElementById('submitFeedbackButton').addEventListener('click', () => {
        const feedback = document.getElementById('feedbackText').value.trim();
        const feedbackMessage = document.getElementById('feedbackMessage');

        if (feedback.length === 0) {
            feedbackMessage.style.color = 'red';
            feedbackMessage.textContent = "Feedback cannot be empty.";
            feedbackMessage.style.display = 'block';
            return;
        }

        // Log to console or save to storage/server
        console.log("User feedback:", feedback);

        // Clear and thank the user
        document.getElementById('feedbackText').value = '';
        feedbackMessage.style.color = 'green';
        feedbackMessage.textContent = "Thank you for your feedback!";
        feedbackMessage.style.display = 'block';

        setTimeout(() => {
            feedbackMessage.style.display = 'none';
        }, 3000);
    });
});

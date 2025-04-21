console.log('adjustTranslate.js loaded');

// Скрываем элементы с атрибутом `jsrenderer`
const jsrendererElements = document.querySelectorAll('[jsrenderer]');
jsrendererElements.forEach(el => {
    el.style.display = 'none';
    console.log('Hidden element with jsrenderer:', el);
});

// Корректировка стилей для заголовка или других элементов
const header = document.querySelector('header');
if (header) {
    header.style.position = 'fixed';
    header.style.top = '0';
    header.style.width = '100%';
    header.style.zIndex = '1000';
    console.log('Header adjusted:', header);
}

// Восстановление событий для ссылок
const links = document.querySelectorAll('a');
links.forEach(link => {
    link.addEventListener('click', (event) => {
        event.preventDefault();
        window.location.href = link.href;
        console.log('Link click event added:', link);
    });
});

console.log('Styles and behaviors adjusted after translation.');
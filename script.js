let isDragging = false;
let offset = { x: 0, y: 0 };
let container = null;

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.type === 'loadPreferences') {
        container = document.getElementById('postal-container');
        const {
            fontSize = 12,
            postalTextColor = '#37b24d',
            distanceColor = '#228be6',
            gpsParenthesisColor = '#ffffff',
            backgroundColor = 'rgba(0, 0, 0, 0.75)',
            position = { left: 50, top: 50 }
        } = data.preferences || {};

        container.style.fontSize = `${fontSize}px`;
        container.style.backgroundColor = backgroundColor;
        container.style.left = `${Math.round(position.left)}px`; // Ensure integers
        container.style.top = `${Math.round(position.top)}px`;

        const postalCode = document.querySelector('.postal-code');
        const distance = document.querySelector('.distance');
        const parenthesis = document.querySelectorAll('.parenthesis, .gps-label');

        postalCode.style.color = postalTextColor;
        distance.style.color = distanceColor;
        parenthesis.forEach((elem) => (elem.style.color = gpsParenthesisColor));

        container.style.webkitFontSmoothing = "antialiased";
        container.style.mozOsxFontSmoothing = "grayscale";
        container.style.textRendering = "geometricPrecision";
        container.style.transform = "translateZ(0)";
    } else if (data.type === 'updateConfig') {
        container = document.getElementById('postal-container');
        const postalCode = document.querySelector('.postal-code');
        const distance = document.querySelector('.distance');
        const parenthesis = document.querySelectorAll('.parenthesis, .gps-label');

        if (data.fontSize) container.style.fontSize = `${data.fontSize}px`;
        if (data.postalTextColor) postalCode.style.color = data.postalTextColor;
        if (data.distanceColor) distance.style.color = data.distanceColor;
        if (data.gpsParenthesisColor) parenthesis.forEach((elem) => (elem.style.color = data.gpsParenthesisColor));
        if (data.backgroundColor) container.style.backgroundColor = data.backgroundColor;
    } else if (data.type === 'updatePostal') {
        const postalCode = document.querySelector('.postal-code');
        const distance = document.querySelector('.distance');

        const distanceValue = parseFloat(data.distance);
        if (isNaN(distanceValue)) {
            distance.textContent = "Error";
        } else {
            postalCode.textContent = data.postal;
            distance.textContent = `${data.distance}`;
        }
    } else if (data.type === 'toggleCursor') {
        if (data.enabled) {
            document.body.style.cursor = 'grab';
            container.style.cursor = 'grab';
        } else {
            document.body.style.cursor = '';
            container.style.cursor = '';
            isDragging = false;
        }
    } else if (data.type === 'hide') {
        const uiElement = document.querySelector('#ui');
        if (uiElement) {
            uiElement.style.display = 'none';
        } else {
            console.error('[Nearest Postal] Could not find the UI element with ID #ui.');
        }
    } else if (data.type === 'show') {
        const uiElement = document.querySelector('#ui');
        if (uiElement) {
            uiElement.style.display = 'block';
        } else {
            console.error('[Nearest Postal] Could not find the UI element with ID #ui.');
        }
    }
});

document.addEventListener('DOMContentLoaded', () => {
    container = document.getElementById('postal-container');
});

document.addEventListener('mousedown', (event) => {
    if (event.button === 0 && container && container.contains(event.target)) {
        isDragging = true;
        offset.x = event.clientX - container.offsetLeft;
        offset.y = event.clientY - container.offsetTop;
        document.body.style.userSelect = 'none';
    }
});

document.addEventListener('mousemove', (event) => {
    if (isDragging && container) {
        const windowWidth = window.innerWidth;
        const windowHeight = window.innerHeight;
        const containerRect = container.getBoundingClientRect();
        let newLeft = event.clientX - offset.x;
        let newTop = event.clientY - offset.y;
        newLeft = Math.max(0, newLeft);
        newLeft = Math.min(windowWidth - containerRect.width, newLeft);
        newTop = Math.max(0, newTop);
        newTop = Math.min(windowHeight - containerRect.height, newTop);
        container.style.left = `${Math.round(newLeft)}px`;
        container.style.top = `${Math.round(newTop)}px`;
    }
});

document.addEventListener('mouseup', () => {
    if (isDragging && container) {
        isDragging = false;
        document.body.style.userSelect = '';

        const roundedLeft = Math.round(container.offsetLeft);
        const roundedTop = Math.round(container.offsetTop);
        container.style.left = `${roundedLeft}px`;
        container.style.top = `${roundedTop}px`;

        fetch('https://nearest-postal/savePosition', {
            method: 'POST',
            body: JSON.stringify({
                position: {
                    left: roundedLeft,
                    top: roundedTop,
                },
            }),
        });
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        isDragging = false;
        document.body.style.pointerEvents = '';
        fetch('https://nearest-postal/closeUI', { method: 'POST' })
            .catch((error) => console.error('[Nearest Postal] Error closing UI:', error));
    }
});

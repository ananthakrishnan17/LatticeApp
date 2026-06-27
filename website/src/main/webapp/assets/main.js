const defaults = {
  heroTitle: 'Elegant POS Platform for Growing Businesses',
  heroSubtitle: 'Bring your billing, stock and insights into one reliable cloud-enabled workflow.',
  contactNumber: '+91-9999999999',
  apkOption: 'none',
  posOption: 'none',
  seoDescription: 'NammaNanaban offers elegant cloud-ready POS solutions for modern retail businesses.',
  seoKeywords: 'NammaNanaban, POS, cloud POS, retail software, APK'
};

function getSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem('nammananabanWebsiteSettings') || '{}');
    return { ...defaults, ...saved };
  } catch (_) {
    return defaults;
  }
}

const settings = getSettings();
document.getElementById('heroTitle').textContent = settings.heroTitle;
document.getElementById('heroSubtitle').textContent = settings.heroSubtitle;
document.getElementById('contactNumber').textContent = settings.contactNumber;
document.querySelector('meta[name="description"]').setAttribute('content', settings.seoDescription);
document.querySelector('meta[name="keywords"]').setAttribute('content', settings.seoKeywords);

const form = document.getElementById('accessForm');
const result = document.getElementById('result');
const contactRegex = /^\+?[0-9]{10,15}$/;
const apkRoutes = Object.freeze({
  none: null,
  standard: '/apk/NammaNanban/mobilepos-latest.apk'
});
const posRoutes = Object.freeze({
  none: null,
  production: 'https://cloud.nammananaban.com/pos'
});

function routeForOption(optionValue, map) {
  if (!Object.prototype.hasOwnProperty.call(map, optionValue)) return null;
  const value = map[optionValue];
  if (!value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith('/')) return `${window.location.origin}${value}`;
  return value;
}

function appendText(node, text) {
  node.appendChild(document.createTextNode(text));
}

form.addEventListener('submit', (event) => {
  event.preventDefault();
  const contact = document.getElementById('contact').value.trim();
  const wantDemo = document.getElementById('wantDemo').checked;
  const isPaid = document.getElementById('isPaid').checked;
  result.replaceChildren();

  if (!contactRegex.test(contact)) {
    result.textContent = 'Please enter a valid contact number (10 to 15 digits, optional +).';
    result.style.color = '#b91c1c';
    return;
  }

  if (!wantDemo && !isPaid) {
    result.textContent = 'Choose demo request or paid access option.';
    result.style.color = '#b91c1c';
    return;
  }

  if (wantDemo) {
    appendText(result, `Our team will contact you at ${contact}. Support: ${settings.contactNumber}. `);
  }
  if (isPaid) {
    appendText(result, 'Paid access: ');
    const apkUrl = routeForOption(settings.apkOption, apkRoutes);
    if (apkUrl) {
      const apkLink = document.createElement('a');
      apkLink.href = apkUrl;
      apkLink.textContent = 'Download APK';
      apkLink.rel = 'noopener';
      result.appendChild(apkLink);
    } else {
      appendText(result, 'APK link is not configured. Contact support. ');
    }
    appendText(result, ' | ');
    const posUrl = routeForOption(settings.posOption, posRoutes);
    if (posUrl) {
      const posLink = document.createElement('a');
      posLink.href = posUrl;
      posLink.target = '_blank';
      posLink.rel = 'noopener noreferrer';
      posLink.textContent = 'Open Cloud POS';
      result.appendChild(posLink);
    } else {
      appendText(result, 'Cloud POS link is not configured. Contact support.');
    }
  }

  result.style.color = '#166534';
});

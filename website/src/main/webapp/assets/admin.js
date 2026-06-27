const defaults = {
  heroTitle: 'Elegant POS Platform for Growing Businesses',
  heroSubtitle: 'Bring your billing, stock and insights into one reliable cloud-enabled workflow.',
  contactNumber: '+91-9999999999',
  apkOption: 'none',
  posOption: 'none',
  seoDescription: 'NammaNanaban offers elegant cloud-ready POS solutions for modern retail businesses.',
  seoKeywords: 'NammaNanaban, POS, cloud POS, retail software, APK'
};

function loadSettings() {
  try {
    return { ...defaults, ...(JSON.parse(localStorage.getItem('nammananabanWebsiteSettings') || '{}')) };
  } catch (_) {
    return defaults;
  }
}

const form = document.getElementById('adminForm');
const status = document.getElementById('saveStatus');
const settings = loadSettings();
const contactRegex = /^\+?[0-9]{10,15}$/;
const allowedApkOptions = new Set(['none', 'standard']);
const allowedPosOptions = new Set(['none', 'production']);

for (const [key, value] of Object.entries(settings)) {
  const field = document.getElementById(key);
  if (field) field.value = value;
}

form.addEventListener('submit', (event) => {
  event.preventDefault();
  const payload = {
    heroTitle: document.getElementById('heroTitle').value.trim(),
    heroSubtitle: document.getElementById('heroSubtitle').value.trim(),
    contactNumber: document.getElementById('contactNumber').value.trim(),
    apkOption: document.getElementById('apkOption').value,
    posOption: document.getElementById('posOption').value,
    seoDescription: document.getElementById('seoDescription').value.trim(),
    seoKeywords: document.getElementById('seoKeywords').value.trim()
  };

  if (!contactRegex.test(payload.contactNumber)) {
    status.textContent = 'Enter a valid contact number (10 to 15 digits, optional +).';
    status.style.color = '#b91c1c';
    return;
  }
  if (!allowedApkOptions.has(payload.apkOption) || !allowedPosOptions.has(payload.posOption)) {
    status.textContent = 'Choose valid APK and Cloud POS options.';
    status.style.color = '#b91c1c';
    return;
  }

  localStorage.setItem('nammananabanWebsiteSettings', JSON.stringify(payload));
  status.textContent = 'Saved. Visitor page now uses updated content and links.';
  status.style.color = '#166534';
});

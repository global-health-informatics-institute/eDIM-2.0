let alertSlides = [];
let alertIndex = 0;
let alertTimer = null;
let alertCooldownTimer = null;

const ALERT_VISIBLE_MS = 10000;
const ALERT_COOLDOWN_MS = 2 * 60 * 1000;

/* Panel Rendering */
function showInventoryAlertPanel(data) {
  const panel = document.getElementById("inventoryAlertPanel");
  const content = document.getElementById("inventoryAlertContent");

  alertSlides = [];
  alertIndex = 0;

  const ALERT_ICONS = {
    'Near Expiry': '⚠️',
    'Low Stock': '⚠️',
    'Packs Running Low': '⚠️'
  };

  // Helper to create slides
  const createSlide = (title, items, color, isPrepack = false) => {
    const icon = ALERT_ICONS[title] || '';

    if (!items.length) return [];

    return items.map(i => {
      if (isPrepack) {
        return `
          <div class="alert-section alert-prepack" data-prepack="true" style="background:#e8f4ff;">
            <div class="alert-title" style="color:${color};">
              <span class="alert-icon">${icon}</span> ${title}
            </div>
            <div class="alert-item prepack-item">
              <strong>${i.drug}</strong><br>
              Remaining packs: <b>${i.remaining_packs}</b>
            </div>
          </div>
        `;
      }

      // Alert messages
      let alertMessage = '';
      if (title === 'Expired!') {
        alertMessage = `<b style="color:red">Expired</b>`;
      } else if (title === 'Near Expiry!') {
        alertMessage = `Expires in <b>${i.days_left} day${i.days_left !== 1 ? 's' : ''}</b>`;
      } else if (title === 'Low Stock!') {
        alertMessage = `Remaining units: <b>${i.remaining}</b>`;
      }

      return `
        <div class="alert-section" style="background:${color === '#d9534f' ? '#fff5f5' : '#fff8e1'};">
          <div class="alert-title" style="color:${color};">
            <span class="alert-icon">${icon}</span> ${title}
          </div>
          <div class="alert-item"
              data-gn="${i.gn_identifier || ''}"
              data-seq="${i.gn_sequence || ''}">
            <strong>${i.drug}</strong><br>
            ${alertMessage}
          </div>
        </div>
      `;
    });
  };

  // Filter and prepare slides
  const nearExpiry = (data.near_expiry || []).filter(i => i.days_left > 0);
  const expired    = (data.near_expiry || []).filter(i => i.days_left <= 0);
  const lowStock   = (data.low_stock || []).filter(i => i.remaining > 0);
  const prepacks   = (data.prepacks_low || []).filter(i => i.remaining_packs > 0);

  if (expired.length) {
    alertSlides.push(...createSlide('Expired!', expired, '#d9534f'));
  }

  if (nearExpiry.length) {
    alertSlides.push(...createSlide('Near Expiry!', nearExpiry, '#f0ad4e'));
  }

  if (lowStock.length) {
    alertSlides.push(...createSlide('Low Stock!', lowStock, '#f0ad4e'));
  }

  if (prepacks.length) {
    alertSlides.push(...createSlide('Packs Running Low!', prepacks, '#0275d8', true));
  }
  if (!alertSlides.length) return;

  // Show first item immediately
  content.innerHTML = alertSlides[0];
  panel.classList.add("show");

  showNextAlert();
}

/* Alert Rotation */

function showNextAlert() {
  if (alertIndex >= alertSlides.length) return;

  const panel = document.getElementById("inventoryAlertPanel");
  const content = document.getElementById("inventoryAlertContent");

  content.innerHTML = alertSlides[alertIndex];
  panel.classList.add("show");

  alertTimer = setTimeout(() => {
    closeInventoryAlert(() => {
      alertIndex++;
      alertCooldownTimer = setTimeout(showNextAlert, ALERT_COOLDOWN_MS);
    });
  }, ALERT_VISIBLE_MS);
}

// Fetching Alerts

function isHomePage() {
  return document.getElementById("home-page-marker") !== null;
}

function fetchInventoryAlerts() {
  if (!isHomePage()) return;

  // Check last shown timestamp
  const lastShown = parseInt(localStorage.getItem("lastInventoryAlertShown") || "0", 10);
  if (Date.now() - lastShown < ALERT_COOLDOWN_MS) {
    // Too soon, skip showing alerts
    return;
  }

  fetch("/alerts/inventory", { headers: { "Accept": "application/json" } })
    .then(res => res.json())
    .then(data => {
      if (
        data.low_stock?.length ||
        data.near_expiry?.length ||
        data.prepacks_low?.length
      ) {
        showInventoryAlertPanel(data);
      }
    })
    .catch(err => console.error("Alert fetch error:", err));
}

/* Events */

document.addEventListener("turbolinks:load", () => {
  fetchInventoryAlerts();
  setInterval(fetchInventoryAlerts, 5 * 60 * 1000);

  const panel = document.getElementById("inventoryAlertPanel");
  const content = document.getElementById("inventoryAlertContent");
  const closeBtn = document.getElementById("closeInventoryAlert");

  closeBtn?.addEventListener("click", e => {
    e.stopPropagation();
    closeInventoryAlert();
  });

  content.addEventListener("click", e => {
    if (e.target.closest("#closeInventoryAlert")) return;

    // Record cooldown immediately on any alert interaction
    localStorage.setItem("lastInventoryAlertShown", Date.now());

    const prepackSection = e.target.closest(".alert-prepack");
    if (prepackSection) {
        window.location.href = "/general_inventory/prepack_labels";
        return;
    }

    const item = e.target.closest(".alert-item");
    if (!item) return;

    const gn = item.dataset.gn;
    const seq = item.dataset.seq;
    if (!gn || !seq) return;

    window.location.href = `/general_inventory/${gn}/${seq}`;
 });

});

/* Close Panel */

function closeInventoryAlert(callback) {
  const panel = document.getElementById("inventoryAlertPanel");

  clearTimeout(alertTimer);

  panel.classList.add("closing");
  panel.classList.remove("show");

  // Record last alert time in localStorage
  localStorage.setItem("lastInventoryAlertShown", Date.now());

  panel.addEventListener("animationend", () => {
    panel.classList.remove("closing");
    callback && callback();
  }, { once: true });
}
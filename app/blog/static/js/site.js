(function () {
  var t = document.getElementById('nav-toggle'), l = document.getElementById('nav-links');
  if (t) t.addEventListener('click', function () { l.classList.toggle('open'); });
  var b = document.getElementById('theme-toggle');
  if (b) b.addEventListener('click', function () {
    var on = document.documentElement.classList.toggle('light-theme');
    try { localStorage.setItem('theme', on ? 'light' : 'dark'); } catch (e) {}
  });
})();

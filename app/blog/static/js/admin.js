(function () {
  var $ = function (id) { return document.getElementById(id); };
  var NOTE_MAX = window.NOTE_MAX || 500;

  function upload(files, ta) {
    var fd = new FormData();
    Array.prototype.forEach.call(files, function (f) { fd.append('files', f); });
    var ph = '\n![uploading…]()\n';
    insert(ta, ph);
    return fetch(window.BLOG_BASE + '/upload', { method: 'POST', body: fd, headers: { 'X-CSRF': window.CSRF } })
      .then(function (r) { return r.json().then(function (j) { if (!r.ok) throw new Error(j.error || 'Upload failed'); return j; }); })
      .then(function (j) {
        ta.value = ta.value.replace(ph, j.files.map(function (f) { return '\n![' + f.name + '](' + f.url + ')\n'; }).join(''));
        ta.dispatchEvent(new Event('input'));
      })
      .catch(function (e) { ta.value = ta.value.replace(ph, ''); alert(e.message); });
  }
  function insert(ta, text) {
    var s = ta.selectionStart || ta.value.length;
    ta.value = ta.value.slice(0, s) + text + ta.value.slice(ta.selectionEnd || s);
    ta.dispatchEvent(new Event('input'));
  }
  function wire(ta, btn, fileInput, count, isNote) {
    if (btn) btn.addEventListener('click', function () { fileInput.click(); });
    if (fileInput) fileInput.addEventListener('change', function () { if (fileInput.files.length) upload(fileInput.files, ta); fileInput.value = ''; });
    ta.addEventListener('paste', function (e) {
      var fs = Array.prototype.filter.call(e.clipboardData.files || [], function (f) { return /^image\//.test(f.type); });
      if (fs.length) { e.preventDefault(); upload(fs, ta); }
    });
    ta.addEventListener('dragover', function (e) { e.preventDefault(); ta.parentNode.classList.add('dragging'); });
    ta.addEventListener('dragleave', function () { ta.parentNode.classList.remove('dragging'); });
    ta.addEventListener('drop', function (e) {
      ta.parentNode.classList.remove('dragging');
      if (e.dataTransfer.files.length) { e.preventDefault(); upload(e.dataTransfer.files, ta); }
    });
    if (count && isNote) {
      var upd = function () {
        var n = NOTE_MAX - ta.value.replace(/!\[[^\]]*\]\([^)]*\)/g, '').length;
        count.textContent = n; count.classList.toggle('over', n < 0);
      };
      ta.addEventListener('input', upd); upd();
    }
    if (isNote === 'quick') ta.addEventListener('input', function () { ta.style.height = 'auto'; ta.style.height = ta.scrollHeight + 'px'; });
  }

  var q = $('qn-body');
  if (q) {
    wire(q, $('qn-img'), $('qn-file'), $('qn-count'), true);
    q.addEventListener('input', function () { q.style.height = 'auto'; q.style.height = q.scrollHeight + 'px'; });
    q.addEventListener('keydown', function (e) { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') q.form.submit(); });
  }

  var ed = $('editor');
  if (ed) {
    var kind = ed.dataset.kind, ta = $('ed-body');
    wire(ta, $('ed-img'), $('ed-file'), $('ed-count'), kind === 'note');
    var ex = ed.querySelector('[name=excerpt]'), exc = $('ex-count');
    if (ex) { var u = function () { exc.textContent = ex.value.length + '/160'; }; ex.addEventListener('input', u); u(); }
    var pv = $('ed-preview');
    ed.querySelectorAll('[data-tab]').forEach(function (b) {
      b.addEventListener('click', function () {
        ed.querySelectorAll('[data-tab]').forEach(function (x) { x.classList.toggle('on', x === b); });
        var show = b.dataset.tab === 'preview';
        ta.hidden = show; pv.hidden = !show;
        if (show) {
          var fd = new FormData(); fd.append('body', ta.value); fd.append('kind', kind);
          fetch(window.BLOG_BASE + '/preview', { method: 'POST', body: fd, headers: { 'X-CSRF': window.CSRF } })
            .then(function (r) { return r.json(); }).then(function (j) { pv.innerHTML = j.html; });
        }
      });
    });
  }
})();

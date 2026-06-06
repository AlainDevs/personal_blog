document.addEventListener('DOMContentLoaded', () => {
  wireAuthForm({
    formId: 'loginForm',
    endpoint: '/api/auth/login',
    fields: ['email', 'password'],
    messageId: 'loginMessage',
    successRedirect: '/',
  });

  wireAuthForm({
    formId: 'registerForm',
    endpoint: '/api/auth/register',
    fields: ['email', 'username', 'password'],
    messageId: 'registerMessage',
    successRedirect: '/',
  });

  wireCommentForm();
  wirePostForm();
  wirePostDeletion();
  wireSettingsForm();
  wireCategoryUi();
});

function wireAuthForm({ formId, endpoint, fields, messageId, successRedirect }) {
  const form = document.getElementById(formId);
  if (!form) return;

  const message = document.getElementById(messageId);
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    setMessage(message, 'Working...', 'text-slate-300');

    const payload = Object.fromEntries(
      fields.map((field) => [field, document.getElementById(field).value]),
    );

    const response = await sendJson(endpoint, 'POST', payload);
    if (response.ok) {
      setMessage(message, response.data.message || 'Success.', 'text-emerald-200');
      window.location.href = successRedirect;
      return;
    }

    setMessage(message, response.data.message || 'Request failed.', 'text-rose-200');
  });
}

function wireCommentForm() {
  const form = document.getElementById('commentForm');
  if (!form) return;

  const message = document.getElementById('commentMessage');
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const postId = form.dataset.postId;
    const content = document.getElementById('commentContent').value;
    setMessage(message, 'Posting comment...', 'text-slate-300');

    const response = await sendJson(`/api/posts/${postId}/comments`, 'POST', {
      content,
    });

    if (response.ok) {
      setMessage(message, 'Comment posted.', 'text-emerald-200');
      window.location.reload();
      return;
    }

    setMessage(message, response.data.message || 'Failed to post comment.', 'text-rose-200');
  });
}

function wirePostForm() {
  const form = document.getElementById('postForm');
  if (!form) return;

  const message = document.getElementById('postMessage');
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const postId = document.getElementById('postId').value;
    const payload = {
      title: document.getElementById('title').value,
      slug: document.getElementById('slug').value,
      content_markdown: document.getElementById('contentMarkdown').value,
      published: document.getElementById('published').checked,
    };
    const endpoint = postId ? `/api/admin/posts/${postId}` : '/api/admin/posts';
    const method = postId ? 'PUT' : 'POST';

    setMessage(message, 'Saving post...', 'text-slate-300');
    const response = await sendJson(endpoint, method, payload);
    if (response.ok) {
      window.location.href = '/admin/posts';
      return;
    }

    setMessage(message, response.data.message || 'Failed to save post.', 'text-rose-200');
  });
}

function wirePostDeletion() {
  document.querySelectorAll('.delete-post-btn').forEach((button) => {
    button.addEventListener('click', async () => {
      if (!window.confirm('Delete this post?')) return;

      const response = await sendJson(`/api/admin/posts/${button.dataset.postId}`, 'DELETE');
      if (response.ok) {
        window.location.reload();
        return;
      }

      window.alert(response.data.message || 'Failed to delete post.');
    });
  });
}

function wireSettingsForm() {
  const form = document.getElementById('settingsForm');
  if (!form) return;

  const checkbox = document.getElementById('registrationEnabled');
  const status = document.getElementById('registrationStatus');
  const message = document.getElementById('settingsMessage');

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    setMessage(message, 'Saving setting...', 'text-slate-300');

    const response = await sendJson('/api/admin/settings/registration', 'PUT', {
      registration_enabled: checkbox.checked,
    });

    if (response.ok) {
      status.textContent = checkbox.checked ? 'Enabled' : 'Disabled';
      setMessage(message, 'Setting saved.', 'text-emerald-200');
      return;
    }

    setMessage(message, response.data.message || 'Failed to save setting.', 'text-rose-200');
  });
}

function wireCategoryUi() {
  const modal = document.getElementById('categoryModal');
  const form = document.getElementById('categoryForm');
  if (!modal || !form) return;

  const title = document.getElementById('categoryModalTitle');
  const id = document.getElementById('categoryId');
  const name = document.getElementById('categoryName');
  const slug = document.getElementById('categorySlug');
  const message = document.getElementById('categoryMessage');

  document.getElementById('newCategoryBtn')?.addEventListener('click', () => {
    title.textContent = 'Create category';
    id.value = '';
    name.value = '';
    slug.value = '';
    setMessage(message, '', 'text-slate-300');
    modal.classList.remove('hidden');
  });

  document.getElementById('closeCategoryModalBtn')?.addEventListener('click', () => {
    modal.classList.add('hidden');
  });

  document.querySelectorAll('.edit-category-btn').forEach((button) => {
    button.addEventListener('click', () => {
      title.textContent = 'Edit category';
      id.value = button.dataset.categoryId || '';
      name.value = button.dataset.categoryName || '';
      slug.value = button.dataset.categorySlug || '';
      setMessage(message, '', 'text-slate-300');
      modal.classList.remove('hidden');
    });
  });

  document.querySelectorAll('.delete-category-btn').forEach((button) => {
    button.addEventListener('click', async () => {
      if (!window.confirm('Delete this category?')) return;

      const response = await sendJson(
        `/api/admin/categories/${button.dataset.categoryId}`,
        'DELETE',
      );
      if (response.ok) {
        window.location.reload();
        return;
      }

      window.alert(response.data.message || 'Failed to delete category.');
    });
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const categoryId = id.value;
    const endpoint = categoryId
      ? `/api/admin/categories/${categoryId}`
      : '/api/admin/categories';
    const method = categoryId ? 'PUT' : 'POST';

    setMessage(message, 'Saving category...', 'text-slate-300');
    const response = await sendJson(endpoint, method, {
      name: name.value,
      slug: slug.value,
    });

    if (response.ok) {
      window.location.reload();
      return;
    }

    setMessage(message, response.data.message || 'Failed to save category.', 'text-rose-200');
  });
}

async function sendJson(url, method, payload) {
  try {
    const options = {
      method,
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    };

    if (payload !== undefined) {
      options.headers['Content-Type'] = 'application/json';
      options.body = JSON.stringify(payload);
    }

    const response = await fetch(url, options);
    const data = await response.json().catch(() => ({}));
    return { ok: response.ok, status: response.status, data };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      data: { message: 'Network error. Please try again.' },
    };
  }
}

function setMessage(element, text, colorClass) {
  if (!element) return;
  element.textContent = text;
  element.classList.remove('text-slate-300', 'text-emerald-200', 'text-rose-200');
  element.classList.add(colorClass);
}

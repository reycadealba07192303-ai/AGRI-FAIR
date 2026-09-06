import { X, Pencil, Trash2, Copy, Play, Pause, Plus, PackageSearch, Package } from 'lucide-react';
import React, { useEffect, useMemo, useState } from 'react';
import {
  fetchMyProducts,
  createProduct,
  updateProduct,
  removeProduct,
  duplicateProduct,
} from '../../../services/clientApi';
import { API_ORIGIN } from '../../../services/authApi';

const RICE_VARIETIES = [
  'Jasmine',
  'Sinandomeng',
  'Brown Rice',
  'Black Rice',
  'Red Rice',
  'Glutinous (Malagkit)',
  'Other',
];

const DEFAULT_WEIGHTS = [1, 5, 10, 25, 50];

const EMPTY_FORM = {
  name: '',
  variety: RICE_VARIETIES[0],
  description: '',
  price: '',
  stock: '',
  lowStockThreshold: 20,
  status: 'active',
  weightTiers: [],
  existingImages: [],
  newImageFiles: [],
};

function stockBadge(p) {
  if (p.status === 'inactive') return { label: 'Inactive', cls: 'inactive' };
  if (Number(p.stock) <= 0) return { label: 'Out of Stock', cls: 'out-of-stock' };
  if (Number(p.stock) <= Number(p.lowStockThreshold ?? 20)) return { label: 'Low Stock', cls: 'pending' };
  return { label: 'In Stock', cls: 'active' };
}

export default function ProductListTab() {
  const [products, setProducts] = useState([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const loadProducts = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetchMyProducts();
      const list = res.data?.products || res.data || [];
      setProducts(Array.isArray(list) ? list : []);
    } catch (err) {
      setError(err.response?.data?.message || 'Could not load products from server.');
      setProducts([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProducts();
  }, []);

  useEffect(() => {
    return () => {
      form.newImageFiles.forEach((f) => URL.revokeObjectURL(f.preview));
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const counts = useMemo(() => {
    const active = products.filter((p) => p.status !== 'inactive').length;
    const outOfStock = products.filter((p) => p.status !== 'inactive' && Number(p.stock) <= 0).length;
    const lowStock = products.filter(
      (p) => p.status !== 'inactive'
        && Number(p.stock) > 0
        && Number(p.stock) <= Number(p.lowStockThreshold ?? 20)
    ).length;
    return { total: products.length, active, lowStock, outOfStock };
  }, [products]);

  const filteredProducts = useMemo(() => {
    return products.filter((p) => {
      const matchesSearch = !search || p.name.toLowerCase().includes(search.toLowerCase());
      const badge = stockBadge(p);
      const matchesStatus =
        statusFilter === 'all' ||
        (statusFilter === 'active' && p.status !== 'inactive') ||
        (statusFilter === 'inactive' && p.status === 'inactive') ||
        (statusFilter === 'out-of-stock' && badge.cls === 'out-of-stock');
      return matchesSearch && matchesStatus;
    });
  }, [products, search, statusFilter]);

  function resetForm() {
    setForm(EMPTY_FORM);
    setEditingId(null);
    setFormError('');
    setShowForm(false);
  }

  function openAdd() {
    setForm(EMPTY_FORM);
    setEditingId(null);
    setFormError('');
    setShowForm(true);
  }

  function openEdit(p) {
    setForm({
      name: p.name || '',
      variety: p.variety || RICE_VARIETIES[0],
      description: p.description || '',
      price: p.price ?? '',
      stock: p.stock ?? '',
      lowStockThreshold: p.lowStockThreshold ?? 20,
      status: p.status || 'active',
      weightTiers: p.weightTiers || [],
      existingImages: p.images || [],
      newImageFiles: [],
    });
    setEditingId(p._id);
    setFormError('');
    setShowForm(true);
  }

  function handleImagesSelected(e) {
    const files = Array.from(e.target.files || []);
    const totalCount = form.existingImages.length + form.newImageFiles.length + files.length;
    if (totalCount > 5) {
      setFormError('Maximum 5 images per product.');
      return;
    }
    const withPreview = files.map((file) => Object.assign(file, { preview: URL.createObjectURL(file) }));
    setForm((f) => ({ ...f, newImageFiles: [...f.newImageFiles, ...withPreview] }));
    e.target.value = '';
  }

  function removeExistingImage(idx) {
    setForm((f) => ({ ...f, existingImages: f.existingImages.filter((_, i) => i !== idx) }));
  }

  function removeNewImage(idx) {
    setForm((f) => {
      const target = f.newImageFiles[idx];
      if (target) URL.revokeObjectURL(target.preview);
      return { ...f, newImageFiles: f.newImageFiles.filter((_, i) => i !== idx) };
    });
  }

  function addWeightTier() {
    const used = form.weightTiers.map((t) => t.weightKg);
    const next = DEFAULT_WEIGHTS.find((w) => !used.includes(w)) || '';
    setForm((f) => ({ ...f, weightTiers: [...f.weightTiers, { weightKg: next, discountPercent: 0 }] }));
  }

  function updateWeightTier(idx, field, value) {
    setForm((f) => ({
      ...f,
      weightTiers: f.weightTiers.map((t, i) => (i === idx ? { ...t, [field]: value } : t)),
    }));
  }

  function removeWeightTier(idx) {
    setForm((f) => ({ ...f, weightTiers: f.weightTiers.filter((_, i) => i !== idx) }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setFormError('');

    if (!form.name.trim() || !form.variety || !form.description.trim() || !form.price || form.stock === '') {
      setFormError('Product name, variety, description, price, and stock are required.');
      return;
    }
    if (form.existingImages.length + form.newImageFiles.length === 0) {
      setFormError('At least one product image is required.');
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        name: form.name,
        variety: form.variety,
        description: form.description,
        price: form.price,
        stock: form.stock,
        lowStockThreshold: form.lowStockThreshold,
        status: form.status,
        weightTiers: form.weightTiers
          .filter((t) => t.weightKg)
          .map((t) => ({ weightKg: Number(t.weightKg), discountPercent: Number(t.discountPercent) || 0 })),
        existingImages: form.existingImages,
        newImageFiles: form.newImageFiles,
      };

      if (editingId) {
        await updateProduct(editingId, payload);
      } else {
        await createProduct(payload);
      }
      resetForm();
      await loadProducts();
    } catch (err) {
      setFormError(err.response?.data?.message || 'Could not save this product.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete(p) {
    try {
      await removeProduct(p._id);
      await loadProducts();
    } catch (err) {
      setError(err.response?.data?.message || 'Could not delete this product.');
    }
  }

  async function handleDuplicate(p) {
    try {
      await duplicateProduct(p._id);
      await loadProducts();
    } catch (err) {
      setError(err.response?.data?.message || 'Could not duplicate this product.');
    }
  }

  async function handleToggleStatus(p) {
    try {
      await updateProduct(p._id, { status: p.status === 'inactive' ? 'active' : 'inactive' });
      await loadProducts();
    } catch (err) {
      setError(err.response?.data?.message || 'Could not update status.');
    }
  }

  return (
    <div className="ap-tab-content">
      <div className="ap-prod-summary">
        <div className="ap-prod-counts">
          <span className="ap-count-chip">
            <b>{counts.total}</b> listed
          </span>
          <span className="ap-count-chip ap-count-chip--good">
            <b>{counts.active}</b> active
          </span>
          {counts.lowStock > 0 && (
            <span className="ap-count-chip ap-count-chip--warn">
              <b>{counts.lowStock}</b> low stock
            </span>
          )}
          {counts.outOfStock > 0 && (
            <span className="ap-count-chip ap-count-chip--bad">
              <b>{counts.outOfStock}</b> out of stock
            </span>
          )}
        </div>

        {!showForm && (
          <button className="ap-btn-primary" type="button" onClick={openAdd}>
            <Plus size={16} strokeWidth={2.5} />
            Add product
          </button>
        )}
      </div>

      {error && <p className="ap-empty-state">{error}</p>}

      {showForm && (
        <div className="ap-panel ap-form-panel">
          <h3>{editingId ? 'Edit Product' : 'New Product'}</h3>
          {formError && <p className="ap-empty-state">{formError}</p>}
          <form className="ap-prod-form" onSubmit={handleSubmit}>
            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Product Name *</label>
                <input
                  type="text"
                  placeholder="e.g. Premium Jasmine Rice"
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  required
                />
              </div>
              <div className="ap-form-field">
                <label>Rice Variety *</label>
                <select
                  value={form.variety}
                  onChange={(e) => setForm((f) => ({ ...f, variety: e.target.value }))}
                >
                  {RICE_VARIETIES.map((v) => (
                    <option key={v} value={v}>{v}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="ap-form-row">
              <div className="ap-form-field" style={{ gridColumn: '1 / -1' }}>
                <label>Description *</label>
                <input
                  type="text"
                  placeholder="Describe your product"
                  value={form.description}
                  onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                  required
                />
              </div>
            </div>

            <div className="ap-form-row">
              <div className="ap-form-field">
                <label>Price per kg (₱) *</label>
                <input
                  type="number"
                  placeholder="0.00"
                  min="1"
                  step="0.01"
                  value={form.price}
                  onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
                  required
                />
              </div>
              <div className="ap-form-field">
                <label>Initial Stock (kg) *</label>
                <input
                  type="number"
                  placeholder="0"
                  min="0"
                  value={form.stock}
                  onChange={(e) => setForm((f) => ({ ...f, stock: e.target.value }))}
                  required
                />
              </div>
              <div className="ap-form-field">
                <label>Low-stock threshold (kg)</label>
                <input
                  type="number"
                  min="0"
                  value={form.lowStockThreshold}
                  onChange={(e) => setForm((f) => ({ ...f, lowStockThreshold: e.target.value }))}
                />
              </div>
              <div className="ap-form-field">
                <label>Status</label>
                <select
                  value={form.status}
                  onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
            </div>

            <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
              <label>Weight options &amp; bulk discount</label>
              <div className="ap-weight-tiers">
                {form.weightTiers.map((t, idx) => {
                  const base = Number(form.price) || 0;
                  const final = base * (Number(t.weightKg) || 0) * (1 - (Number(t.discountPercent) || 0) / 100);
                  return (
                    <div className="ap-weight-tier-row" key={idx}>
                      <select
                        value={t.weightKg}
                        onChange={(e) => updateWeightTier(idx, 'weightKg', e.target.value)}
                      >
                        <option value="">kg</option>
                        {DEFAULT_WEIGHTS.map((w) => (
                          <option key={w} value={w}>{w} kg</option>
                        ))}
                      </select>
                      <div className="ap-weight-tier-discount">
                        <input
                          type="number"
                          min="0"
                          max="100"
                          value={t.discountPercent}
                          onChange={(e) => updateWeightTier(idx, 'discountPercent', e.target.value)}
                        />
                        <span>% off</span>
                      </div>
                      <span className="ap-weight-tier-final">
                        = ₱{final > 0 ? final.toLocaleString(undefined, { maximumFractionDigits: 2 }) : '—'}
                      </span>
                      <button type="button" className="ap-icon-btn delete" onClick={() => removeWeightTier(idx)} aria-label="Remove tier"><X size={13} strokeWidth={2.6} /></button>
                    </div>
                  );
                })}
                <button type="button" className="ap-btn-ghost" onClick={addWeightTier}>+ Add weight option</button>
              </div>
            </div>

            <div className="ap-form-field" style={{ marginBottom: '0.9rem' }}>
              <label>Images * (max 5)</label>
              <div className="ap-image-grid">
                {form.existingImages.map((src, idx) => (
                  <div className="ap-image-thumb" key={`existing-${idx}`}>
                    <img src={`${API_ORIGIN}${src}`} alt="Product" />
                    <button type="button" onClick={() => removeExistingImage(idx)} aria-label="Remove image"><X size={13} strokeWidth={2.6} /></button>
                  </div>
                ))}
                {form.newImageFiles.map((file, idx) => (
                  <div className="ap-image-thumb" key={`new-${idx}`}>
                    <img src={file.preview} alt="New upload" />
                    <button type="button" onClick={() => removeNewImage(idx)} aria-label="Remove image"><X size={13} strokeWidth={2.6} /></button>
                  </div>
                ))}
                {form.existingImages.length + form.newImageFiles.length < 5 && (
                  <label className="ap-image-upload-btn">
                    +
                    <input type="file" accept="image/*" multiple onChange={handleImagesSelected} hidden />
                  </label>
                )}
              </div>
            </div>

            <div className="ap-form-actions">
              <button type="button" className="ap-btn-ghost" onClick={resetForm}>Cancel</button>
              <button type="submit" className="ap-btn-primary" disabled={submitting}>
                {submitting ? 'Saving…' : editingId ? 'Save Changes' : 'Add Product'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="ap-panel">
        <div className="ap-panel-header">
          <div className="ap-toolbar">
            <input
              type="text"
              className="ap-search-input"
              placeholder="Search products…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="all">All status</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="out-of-stock">Out of Stock</option>
            </select>
          </div>
        </div>
        {loading ? (
          <div className="ap-prod-skeletons">
            {[0, 1, 2, 3].map((i) => <div key={i} className="ap-skeleton" style={{ height: 56 }} />)}
          </div>
        ) : filteredProducts.length === 0 ? (
          <div className="ap-empty-state">
            {products.length === 0 ? <Package size={28} strokeWidth={1.6} /> : <PackageSearch size={28} strokeWidth={1.6} />}
            <p>
              {products.length === 0
                ? 'No products listed yet. Add your first product to start selling.'
                : 'No products match this search or filter.'}
            </p>
            {products.length === 0 && !showForm && (
              <button className="ap-btn-primary" type="button" onClick={openAdd}>
                <Plus size={16} strokeWidth={2.5} />
                Add product
              </button>
            )}
          </div>
        ) : (
          <div className="ap-table-wrap">
            <table className="ap-table ap-prod-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th className="ap-th-num">Price</th>
                  <th>Stock</th>
                  <th>Status</th>
                  <th className="ap-th-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredProducts.map((p) => {
                  const badge = stockBadge(p);
                  const threshold = Number(p.lowStockThreshold ?? 20);
                  const stock = Number(p.stock ?? 0);
                  // Full bar at 2x the low-stock threshold - a sensible "healthy" mark.
                  const fillPct = Math.min(100, (stock / Math.max(threshold * 2, 1)) * 100);

                  return (
                    <tr key={p._id}>
                      <td>
                        <div className="ap-prod-cell">
                          {p.images?.[0] ? (
                            <img src={`${API_ORIGIN}${p.images[0]}`} alt="" className="ap-row-thumb" />
                          ) : (
                            <div className="ap-row-thumb ap-row-thumb-empty">
                              <Package size={16} strokeWidth={2} />
                            </div>
                          )}
                          <div className="ap-prod-cell-text">
                            <span className="ap-prod-name">{p.name}</span>
                            <span className="ap-prod-variety">{p.variety || 'No variety set'}</span>
                          </div>
                        </div>
                      </td>

                      <td className="ap-td-num">
                        {p.price != null ? (
                          <>
                            <span className="ap-price">₱{Number(p.price).toLocaleString()}</span>
                            <span className="ap-price-unit">/kg</span>
                          </>
                        ) : '—'}
                      </td>

                      <td>
                        <div className="ap-stock-cell">
                          <span className="ap-stock-value">{stock.toLocaleString()} kg</span>
                          <div className="ap-stock-bar-track">
                            <div
                              className={`ap-stock-bar-fill ap-stock-bar-${badge.cls}`}
                              style={{ width: `${Math.max(3, fillPct)}%` }}
                            />
                          </div>
                        </div>
                      </td>

                      <td>
                        <span className={`ap-badge ap-badge-${badge.cls}`}>{badge.label}</span>
                      </td>

                      <td>
                        <div className="ap-row-actions">
                          <button className="ap-icon-btn" type="button" onClick={() => openEdit(p)} title="Edit">
                            <Pencil size={15} strokeWidth={2.2} />
                          </button>
                          <button className="ap-icon-btn" type="button" onClick={() => handleDuplicate(p)} title="Duplicate">
                            <Copy size={15} strokeWidth={2.2} />
                          </button>
                          <button
                            className="ap-icon-btn"
                            type="button"
                            onClick={() => handleToggleStatus(p)}
                            title={p.status === 'inactive' ? 'Set active' : 'Set inactive'}
                          >
                            {p.status === 'inactive'
                              ? <Play size={15} strokeWidth={2.2} />
                              : <Pause size={15} strokeWidth={2.2} />}
                          </button>
                          <button className="ap-icon-btn delete" type="button" onClick={() => handleDelete(p)} title="Delete">
                            <Trash2 size={15} strokeWidth={2.2} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

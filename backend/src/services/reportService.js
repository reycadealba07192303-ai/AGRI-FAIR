import * as orderRepo from '../repositories/orderRepository.js';
import * as inventoryRepo from '../repositories/inventoryRepository.js';
import { findUserByUserId } from '../repositories/userRepository.js';
import { sendMail, isMailConfigured } from '../config/mailer.js';
import { buildPdf } from './pdfReport.js';

const peso = (n) =>
  `PHP ${Number(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

const shortDate = (d) =>
  d ? new Date(d).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';

const titleCase = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : '—');

/** Short covering note; the numbers themselves live in the attached PDF. */
function mailBody(seller, heading, lines) {
  return `
  <div style="font-family:Arial,Helvetica,sans-serif;color:#1a2e1a;max-width:560px;margin:0 auto;padding:24px">
    <div style="border-bottom:3px solid #2d5a2d;padding-bottom:12px;margin-bottom:18px">
      <h1 style="margin:0;font-size:19px;color:#0f1d10">AgriFair</h1>
      <p style="margin:4px 0 0;font-size:13px;color:#6b7268">${heading}</p>
    </div>
    <p style="font-size:14px;line-height:1.6;margin:0 0 14px">
      Hi ${seller.name || 'there'}, your report is attached as a PDF.
    </p>
    <table style="width:100%;border-collapse:collapse;margin-bottom:16px">
      ${lines.map((l) => `
        <tr>
          <td style="padding:6px 0;font-size:13px;color:#6b7268">${l.label}</td>
          <td style="padding:6px 0;font-size:13px;font-weight:bold;text-align:right">${l.value}</td>
        </tr>`).join('')}
    </table>
    <p style="font-size:12px;color:#6b7268;line-height:1.6;margin:0">
      Generated ${shortDate(new Date())}.
    </p>
    <p style="margin-top:24px;font-size:11px;color:#8a948a;border-top:1px solid #e4e4e0;padding-top:12px">
      Sent because you requested this report from your AgriFair seller dashboard.
    </p>
  </div>`;
}

// ---------------------------------------------------------------- builders

async function salesReport(sellerId, seller) {
  const [orders, analytics] = await Promise.all([
    orderRepo.findOrdersBySeller(sellerId, { status: 'completed' }),
    orderRepo.getSellerAnalytics(sellerId),
  ]);

  const summary = [
    { label: 'Total sales', value: peso(analytics.totalSales) },
    { label: 'Completed orders', value: analytics.orderCount },
    { label: 'Average order', value: peso(analytics.avgOrderValue) },
  ];

  const pdf = await buildPdf({
    title: 'Sales report',
    subtitle: `${seller.name || seller.email} · ${shortDate(new Date())}`,
    summary,
    columns: [
      { label: 'Order', key: 'order', width: 90, strong: true },
      { label: 'Buyer', key: 'buyer', width: 120 },
      { label: 'Product', key: 'product', width: 130 },
      { label: 'Qty', key: 'qty', width: 55, align: 'right' },
      { label: 'Total', key: 'total', width: 90, align: 'right', strong: true },
      { label: 'Date', key: 'date', width: 80, align: 'right' },
    ],
    rows: orders.map((o) => ({
      order: o.orderNumber || '—',
      buyer: o.customerName,
      product: o.productName,
      qty: `${o.quantity} kg`,
      total: peso(o.total),
      date: shortDate(o.orderDate),
    })),
    emptyText: 'No completed sales recorded yet.',
  });

  return {
    pdf,
    filename: 'agrifair-sales-report.pdf',
    subject: 'Your AgriFair sales report',
    html: mailBody(seller, 'Sales report', summary),
  };
}

async function inventoryReport(sellerId, seller) {
  const data = await inventoryRepo.getInventorySummary(sellerId);
  const products = data?.products || [];

  const summary = [
    { label: 'Total stock', value: `${(data?.totalStock || 0).toLocaleString()} kg` },
    { label: 'Stock value', value: peso(data?.stockValue) },
    { label: 'Running low', value: data?.lowStockCount || 0 },
  ];

  const pdf = await buildPdf({
    title: 'Inventory report',
    subtitle: `${seller.name || seller.email} · ${shortDate(new Date())}`,
    summary,
    columns: [
      { label: 'Product', key: 'product', width: 170, strong: true },
      { label: 'Stock', key: 'stock', width: 80, align: 'right' },
      { label: 'Warn at', key: 'warn', width: 70, align: 'right' },
      { label: 'Status', key: 'status', width: 90 },
      { label: 'Value', key: 'value', width: 100, align: 'right', strong: true },
    ],
    rows: products.map((p) => {
      const stock = Number(p.stock ?? 0);
      const threshold = Number(p.lowStockThreshold ?? 20);
      return {
        product: p.name,
        stock: `${stock.toLocaleString()} kg`,
        warn: `${threshold} kg`,
        status: stock <= 0 ? 'Out of stock' : stock <= threshold ? 'Low' : 'In stock',
        value: peso(stock * Number(p.price || 0)),
      };
    }),
    emptyText: 'No products listed yet.',
  });

  return {
    pdf,
    filename: 'agrifair-inventory-report.pdf',
    subject: 'Your AgriFair inventory report',
    html: mailBody(seller, 'Inventory report', summary),
  };
}

async function transactionsReport(sellerId, seller) {
  const orders = await orderRepo.findOrdersBySeller(sellerId);

  const paid = orders.filter((o) => o.paymentStatus === 'paid');
  const received = paid.reduce((sum, o) => sum + Number(o.amountPaid || 0), 0);

  const summary = [
    { label: 'All orders', value: orders.length },
    { label: 'Paid', value: paid.length },
    { label: 'Money received', value: peso(received) },
  ];

  const pdf = await buildPdf({
    title: 'Transactions',
    subtitle: `${seller.name || seller.email} · ${shortDate(new Date())}`,
    summary,
    columns: [
      { label: 'Order', key: 'order', width: 85, strong: true },
      { label: 'Buyer', key: 'buyer', width: 105 },
      { label: 'Method', key: 'method', width: 75 },
      { label: 'Payment', key: 'payment', width: 80 },
      { label: 'Order status', key: 'status', width: 85 },
      { label: 'Total', key: 'total', width: 85, align: 'right', strong: true },
      { label: 'Date', key: 'date', width: 75, align: 'right' },
    ],
    rows: orders.map((o) => ({
      order: o.orderNumber || '—',
      buyer: o.customerName,
      method: o.paymentMethod || 'Cash/COD',
      payment: titleCase((o.paymentStatus || 'unpaid').replace('_', ' ')),
      status: titleCase(o.status),
      total: peso(o.total),
      date: shortDate(o.orderDate),
    })),
    emptyText: 'No transactions recorded yet.',
  });

  return {
    pdf,
    filename: 'agrifair-transactions.pdf',
    subject: 'Your AgriFair transactions',
    html: mailBody(seller, 'Transactions', summary),
  };
}

const BUILDERS = {
  sales: salesReport,
  inventory: inventoryReport,
  transactions: transactionsReport,
};

/**
 * Emails a report as a PDF. The recipient is always the seller's own account
 * address — there is no "send to" input, so this cannot be used to mail one
 * business's figures to an outsider.
 */
export const emailReport = async (sellerId, type) => {
  const build = BUILDERS[type];
  if (!build) throw new Error('Unknown report type');

  if (!isMailConfigured()) {
    throw new Error(
      'Email is not set up yet. Add SMTP_HOST, SMTP_USER and SMTP_PASS to backend/.env, then restart the server.'
    );
  }

  const seller = await findUserByUserId(sellerId);
  if (!seller?.email) throw new Error('Your account has no email address on file.');

  const { pdf, filename, subject, html } = await build(sellerId, seller);

  await sendMail({
    to: seller.email,
    subject,
    html,
    attachments: [{ filename, content: pdf, contentType: 'application/pdf' }],
  });

  return { sent: true, to: seller.email };
};

export const mailStatus = () => ({ configured: isMailConfigured() });

/**
 * Shared transactional email layout for DRIVEPAL (slate + teal branding).
 * Safe for HTML body copy: escape user-controlled strings before interpolating.
 */

export interface DrivepalMailCta {
  label: string;
  href: string;
}

export interface DrivepalMailContent {
  /** Email subject line; defaults to [title]. */
  subject?: string;
  /** Short inbox preview line (hidden in body via preheader trick). */
  preheader: string;
  /** Main heading inside the card. */
  title: string;
  /** Paragraphs shown as stacked body copy. */
  paragraphs: string[];
  /** Primary action (optional). */
  cta?: DrivepalMailCta;
  /** Smaller line under CTA (e.g. link expiry). */
  footnote?: string;
}

const brandBg = '#0f172a';
const accent = '#14b8a6';
const textMain = '#334155';
const textMuted = '#64748b';

export function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Build multipart email: HTML + plain text (fallback). */
export function buildDrivepalMail(content: DrivepalMailContent): {
  subject: string;
  html: string;
  text: string;
} {
  const title = escapeHtml(content.title);
  const pre = escapeHtml(content.preheader);
  const parasHtml = content.paragraphs.map(
    (p) =>
      `<p style="margin:0 0 16px;line-height:1.55;color:${textMain};font-size:15px;">${escapeHtml(p)}</p>`,
  );
  const parasText = content.paragraphs.join('\n\n');

  let ctaHtml = '';
  let ctaText = '';
  if (content.cta) {
    const label = escapeHtml(content.cta.label);
    const href = content.cta.href; // trusted URL from our backend
    ctaHtml = `
<table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px 0;">
  <tr>
    <td align="center" style="border-radius:12px;background:${accent};">
      <a href="${href}" target="_blank" rel="noopener noreferrer"
        style="display:inline-block;padding:14px 28px;font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:12px;">${label}</a>
    </td>
  </tr>
</table>`;
    ctaText = `${content.cta.label}: ${href}\n`;
  }

  let footHtml = '';
  let footText = '';
  if (content.footnote) {
    footHtml = `<p style="margin:16px 0 0;font-size:13px;line-height:1.5;color:${textMuted};">${escapeHtml(content.footnote)}</p>`;
    footText = `\n\n${content.footnote}`;
  }

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:${brandBg};">
  <div style="display:none;font-size:1px;color:${brandBg};line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    ${pre}
  </div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:${brandBg};">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 10px 40px rgba(15,23,42,0.25);">
          <tr>
            <td style="background:${brandBg};padding:28px 32px;text-align:center;border-bottom:3px solid ${accent};">
              <span style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:18px;font-weight:700;letter-spacing:0.22em;color:#f8fafc;">DRIVEPAL</span>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 32px 8px;font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
              <h1 style="margin:0 0 20px;font-size:22px;font-weight:600;color:${brandBg};letter-spacing:-0.02em;">${title}</h1>
              ${parasHtml.join('')}
              ${ctaHtml}
              ${footHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:0 32px 28px;font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:${textMuted};">
              <p style="margin:0;">You received this because of an action on your DRIVEPAL account. If this wasn’t you, you can safely ignore this email.</p>
            </td>
          </tr>
        </table>
        <p style="margin:24px 0 0;font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;color:#94a3b8;">© ${new Date().getFullYear()} DRIVEPAL</p>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = `${content.title}\n\n${parasText}\n\n${ctaText}${footText}\n\n— DRIVEPAL`;

  return {
    subject: content.subject ?? content.title,
    html,
    text,
  };
}

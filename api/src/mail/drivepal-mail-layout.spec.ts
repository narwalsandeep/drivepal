import { buildDrivepalMail, escapeHtml } from './drivepal-mail-layout';

describe('escapeHtml', () => {
  it('escapes special characters', () => {
    expect(escapeHtml('<script>')).toBe('&lt;script&gt;');
    expect(escapeHtml('a & b')).toBe('a &amp; b');
    expect(escapeHtml('"x"')).toBe('&quot;x&quot;');
  });
});

describe('buildDrivepalMail', () => {
  it('uses custom subject when provided', () => {
    const { subject } = buildDrivepalMail({
      subject: 'Custom subject',
      preheader: 'pre',
      title: 'Title',
      paragraphs: ['One'],
    });
    expect(subject).toBe('Custom subject');
  });

  it('escapes paragraph text in html', () => {
    const { html } = buildDrivepalMail({
      preheader: 'pre',
      title: 'Hi',
      paragraphs: ['<b>evil</b>'],
    });
    expect(html).toContain('&lt;b&gt;evil&lt;/b&gt;');
    expect(html).not.toContain('<b>evil</b>');
  });
});

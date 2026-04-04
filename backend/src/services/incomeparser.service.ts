// eslint-disable-next-line @typescript-eslint/no-require-imports
const { PDFParse } = require('pdf-parse') as {
  PDFParse: new (opts: { data: Buffer }) => {
    getText(): Promise<{ text: string }>;
    destroy?: () => Promise<void> | void;
  };
};

export interface ParsedIncome {
  grossPerPeriod: number;
  payPeriod: 'weekly' | 'biweekly' | 'semimonthly' | 'monthly';
  grossMonthly: number;
  employer: string;
}

const MONTHLY_MULTIPLIERS: Record<string, number> = {
  weekly:      52 / 12,
  biweekly:    26 / 12,
  semimonthly: 2,
  monthly:     1,
};

export async function parseIncomeFromDocument(
  buffer: Buffer,
  mimetype: string
): Promise<ParsedIncome> {
  let text = '';

  if (mimetype === 'application/pdf') {
    const parser = new PDFParse({ data: buffer });
    try {
      const result = await parser.getText();
      text = result.text;
    } finally {
      await parser.destroy?.();
    }
  } else {
    throw new Error('Unsupported file type. Please upload a PDF paystub.');
  }

  return parseIncomeFromText(text);
}

function parseIncomeFromText(text: string): ParsedIncome {
  const normalised = text.replace(/\r\n/g, '\n');

  // --- Gross pay amount ---
  // Try labeled patterns first (most reliable)
  const grossPatterns = [
    /gross\s+(?:pay|earnings?|wages?|income)\s*[:\-]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /(?:total\s+)?gross\s+[:\-]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /\$\s*([\d,]+\.\d{2})\s*(?:gross)/i,
    // YTD column is often next to current-period: take the smaller number
  ];

  let grossPerPeriod = 0;
  for (const pattern of grossPatterns) {
    const m = pattern.exec(normalised);
    if (m) {
      grossPerPeriod = parseFloat(m[1].replace(/,/g, ''));
      break;
    }
  }

  // Fallback: find all dollar amounts, take the largest one that looks like a pay amount
  if (!grossPerPeriod) {
    const allAmounts = [...normalised.matchAll(/\$([\d,]+\.\d{2})/g)]
      .map(m => parseFloat(m[1].replace(/,/g, '')))
      .filter(n => n > 0 && n < 50_000)
      .sort((a, b) => b - a);
    if (allAmounts.length) grossPerPeriod = allAmounts[0];
  }

  if (!grossPerPeriod) {
    throw new Error('Could not find a gross pay amount in the document.');
  }

  // --- Pay frequency ---
  const freqTests: [RegExp, ParsedIncome['payPeriod']][] = [
    [/\bsemi[\s-]?monthly\b/i, 'semimonthly'],
    [/\bmonthly\b/i,           'monthly'],
    [/\bbi[\s-]?weekly\b/i,    'biweekly'],
    [/\bevery\s+(?:two|2)\s+weeks?\b/i, 'biweekly'],
    [/\bweekly\b/i,            'weekly'],
  ];

  let payPeriod: ParsedIncome['payPeriod'] = 'biweekly'; // safest default
  for (const [re, freq] of freqTests) {
    if (re.test(normalised)) { payPeriod = freq; break; }
  }

  const grossMonthly = grossPerPeriod * MONTHLY_MULTIPLIERS[payPeriod];

  // --- Employer name ---
  const employerPatterns = [
    /(?:employer|company|pay(?:er|roll)\s+company)\s*[:\-]\s*(.+)/i,
    /(?:from|issued\s+by)\s*[:\-]?\s*([A-Z][^\n]{2,40})/,
    // First line of the document is often the employer header
    /^([A-Z][A-Za-z0-9 &,.']{2,40})\n/,
  ];

  let employer = 'Unknown Employer';
  for (const pattern of employerPatterns) {
    const m = pattern.exec(normalised);
    if (m) { employer = m[1].trim().slice(0, 60); break; }
  }

  return { grossPerPeriod, payPeriod, grossMonthly, employer };
}

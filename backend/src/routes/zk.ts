import { Router, Request, Response } from 'express';
import multer from 'multer';
import { parseIncomeFromDocument } from '../services/incomeparser.service';
import { generateIncomeProof } from '../services/zkproof.service';

const router = Router();

// Store files in memory — we only need the buffer to parse, never persist
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are supported. Please upload a PDF paystub.'));
    }
  },
});

// POST /api/zk/prove
// Accepts a multipart/form-data PDF upload, parses gross income, returns ZK commitment proof.
router.post('/prove', upload.single('document'), async (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No document uploaded. Send the PDF as form-data field "document".' });
  }

  try {
    const parsed = await parseIncomeFromDocument(req.file.buffer, req.file.mimetype);
    const proof  = generateIncomeProof(parsed.grossMonthly);

    if (!proof.eligible) {
      // Still return the proof — the app will handle ineligibility messaging
      console.log(`ZK: income ${parsed.grossMonthly.toFixed(2)}/mo exceeds threshold — ineligible`);
    } else {
      console.log(`ZK: income ${parsed.grossMonthly.toFixed(2)}/mo — eligible`);
    }

    res.json({
      proof:         proof.commitment,
      publicSignals: proof.publicSignals,
      isValid:       proof.eligible,
      // Non-sensitive metadata for display in the app
      payPeriod:     parsed.payPeriod,
      employer:      parsed.employer,
    });
  } catch (err: any) {
    console.error('ZK prove error:', err.message);
    res.status(422).json({ error: err.message });
  }
});

export default router;

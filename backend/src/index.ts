import express from 'express';
import { config } from './config';
import authRoutes       from './routes/auth';
import worldIDRoutes    from './routes/worldid';
import zkRoutes         from './routes/zk';
import blockchainRoutes from './routes/blockchain';

const app = express();
app.use(express.json());

// Health check
app.get('/health', (_req, res) => res.json({ ok: true, env: config.hedera.network }));

// Routes
app.use('/api/auth',       authRoutes);
app.use('/api/worldid',    worldIDRoutes);
app.use('/api/zk',         zkRoutes);
app.use('/api/blockchain', blockchainRoutes);

app.listen(config.port, () => {
  console.log(`Equitas backend running on port ${config.port}`);
  console.log(`World ID app: ${config.worldID.appID}`);
  console.log(`Hedera network: ${config.hedera.network}`);
});

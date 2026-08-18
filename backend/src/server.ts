import express from 'express';
import cors from 'cors';
import { config } from './config/env';
import routes from './routes';

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(routes);

app.listen(config.port, () => {
  console.log(`Nexora backend listening on http://localhost:${config.port}`);
});

const express = require('express');
const app = express();
app.get('/', (req, res) => res.send('Clean build!'));
app.listen(3000);

const fs = require('fs');

async function test() {
  try {
    const url = 'https://fonts.gstatic.com/s/notosansjp/v53/-F6jfjtqLzI2JPCgQBnw7HFyzSD-AsregP8VFBEj75vY0rw-oME.ttf';
    console.log('Fetching:', url);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
    const buffer = await res.arrayBuffer();
    fs.writeFileSync('test_noto.ttf', Buffer.from(buffer));
    console.log('Success! Downloaded font of size:', buffer.byteLength);
  } catch (err) {
    console.error('Failed to download:', err.message);
  }
}

test();

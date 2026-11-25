// Conta os pedidos do KubeShop autenticando como admin (senha lida de arquivo,
// nunca da linha de comando). Uso: mongosh --quiet --file /opt/count-orders.js
const fs = require('fs');
const pwd = fs.readFileSync('/run/secrets/mongo_root_password', 'utf8').trim();
const admin = db.getSiblingDB('admin');
if (!admin.auth('admin', pwd).ok) quit(1);
const shop = db.getSiblingDB('kubeshop');
const last = shop.orders.find({}, { _id: 1, createdAt: 1 }).sort({ createdAt: -1 }).limit(1).toArray()[0];
print(JSON.stringify({
  orders: shop.orders.countDocuments({}),
  lastOrderId: last ? last._id.toString() : null,
  lastOrderAt: last ? last.createdAt : null,
}));

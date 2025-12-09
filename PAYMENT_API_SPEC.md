# Payment Backend API Specification

## Base URL
```
https://flip-backend-mnpg.onrender.com/api
```

## Authentication
All endpoints require Bearer token authentication:
```
Authorization: Bearer <token>
```

---

## 1. Payment Method Management

### Set Preferred Payment Method
```http
POST /payments/set-preferred-method
Content-Type: application/json
Authorization: Bearer <token>

{
  "paymentMethod": "ancient_flip_pay" | "google_pay" | "paystack" | "app_store"
}

Response (200):
{
  "success": true,
  "data": {
    "userId": "...",
    "preferredMethod": "ancient_flip_pay",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}

Response (4xx):
{
  "success": false,
  "message": "Invalid payment method"
}
```

### Get Available Payment Methods
```http
GET /payments/available-methods
Authorization: Bearer <token>

Response (200):
{
  "data": {
    "methods": [
      "ancient_flip_pay",
      "google_pay",
      "paystack",
      "app_store"
    ]
  }
}
```

### Get Preferred Payment Method
```http
GET /payments/preferred-method
Authorization: Bearer <token>

Response (200):
{
  "data": {
    "method": "ancient_flip_pay"
  }
}

Response (404):
{
  "data": {
    "method": null
  }
}
```

---

## 2. AncientFlip Pay Processing

### Process AncientFlip Pay Purchase
```http
POST /payments/process-ancient-flip-pay
Content-Type: application/json
Authorization: Bearer <token>

{
  "packageId": "coins_100",
  "amount": 100,
  "description": "Purchase 100 coins",
  "paymentMethod": "ancient_flip_pay"
}

Response (200):
{
  "success": true,
  "data": {
    "transactionId": "txn_1234567890",
    "coinsAdded": 100,
    "newBalance": 500,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}

Response (400):
{
  "success": false,
  "message": "Insufficient balance"
}

Response (401):
{
  "success": false,
  "message": "Unauthorized"
}
```

---

## 3. Paystack Integration

### Initialize Paystack Transaction
```http
POST /payments/paystack/initialize
Content-Type: application/json
Authorization: Bearer <token>

{
  "amount": 5000,           // Amount in kobo/cents (5000 = GHS 50.00)
  "email": "user@example.com",
  "currency": "GHS"         // GHS, NGN, ZAR, KES
}

Response (200):
{
  "success": true,
  "data": {
    "reference": "pay_xyz789abc123",
    "authorization_url": "https://checkout.paystack.com/...",
    "access_code": "access_xyz789abc123"
  }
}

Response (400):
{
  "success": false,
  "message": "Invalid amount or currency"
}
```

### Verify Paystack Payment
```http
POST /payments/paystack/verify
Content-Type: application/json
Authorization: Bearer <token>

{
  "reference": "pay_xyz789abc123",
  "coinAmount": 100  // Coins to add to user
}

Response (200):
{
  "success": true,
  "data": {
    "transactionId": "txn_1234567890",
    "reference": "pay_xyz789abc123",
    "coinsAdded": 100,
    "newBalance": 600,
    "paymentStatus": "success",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}

Response (400):
{
  "success": false,
  "message": "Payment verification failed",
  "reason": "Invalid reference"
}

Response (402):
{
  "success": false,
  "message": "Payment not completed",
  "paymentStatus": "pending"
}
```

---

## 4. Google Play IAP

### Verify Google Play Purchase
```http
POST /payments/google-play/verify
Content-Type: application/json
Authorization: Bearer <token>

{
  "productId": "com.flip.coins.pack_100",
  "purchaseToken": "ahjcbdkahjbcjkabcjkabcjk",
  "coinAmount": 100
}

Response (200):
{
  "success": true,
  "data": {
    "transactionId": "txn_1234567890",
    "orderId": "GPA.1234-5678-9012-34567",
    "productId": "com.flip.coins.pack_100",
    "coinsAdded": 100,
    "newBalance": 700,
    "purchaseTime": "2024-01-15T10:30:00Z"
  }
}

Response (400):
{
  "success": false,
  "message": "Invalid purchase token"
}

Response (402):
{
  "success": false,
  "message": "Purchase verification failed with Google"
}
```

---

## 5. App Store IAP

### Verify App Store Purchase
```http
POST /payments/app-store/verify
Content-Type: application/json
Authorization: Bearer <token>

{
  "productId": "com.flip.coins.pack_100",
  "receipt": "base64_encoded_receipt_data",
  "coinAmount": 100
}

Response (200):
{
  "success": true,
  "data": {
    "transactionId": "txn_1234567890",
    "bundleId": "com.flip.app",
    "productId": "com.flip.coins.pack_100",
    "coinsAdded": 100,
    "newBalance": 700,
    "purchaseTime": "2024-01-15T10:30:00Z"
  }
}

Response (400):
{
  "success": false,
  "message": "Invalid receipt"
}

Response (402):
{
  "success": false,
  "message": "Purchase verification failed with Apple"
}
```

---

## 6. Transaction History (Expected Future)

### Get Transaction History
```http
GET /payments/transactions?type=purchase&limit=20&offset=0
Authorization: Bearer <token>

Response (200):
{
  "data": {
    "transactions": [
      {
        "id": "txn_1234567890",
        "type": "purchase",
        "currency": "coins",
        "amount": 100,
        "balanceAfter": 700,
        "status": "completed",
        "payment": {
          "method": "paystack",
          "reference": "pay_xyz789abc123"
        },
        "createdAt": "2024-01-15T10:30:00Z"
      }
    ],
    "total": 45,
    "limit": 20,
    "offset": 0
  }
}
```

---

## 7. Error Response Format

### Standard Error Response
```json
{
  "success": false,
  "message": "User-friendly error message",
  "errorCode": "PAYMENT_001",
  "details": {
    "field": "amount",
    "reason": "Amount must be positive"
  }
}
```

### Common Error Codes
```
PAYMENT_001   - Invalid amount
PAYMENT_002   - Invalid payment method
PAYMENT_003   - Insufficient balance
PAYMENT_004   - Payment not found
PAYMENT_005   - Payment verification failed
AUTH_001      - Unauthorized
AUTH_002      - Invalid token
AUTH_003      - Token expired
NETWORK_001   - External API error
NETWORK_002   - Timeout
```

---

## 8. Rate Limiting

Recommended rate limits:
```
Payment Method Endpoints: 100 requests/minute per user
Payment Processing: 10 requests/minute per user
Verification: 30 requests/minute per user
History: 100 requests/minute per user
```

---

## 9. Webhook Events (Optional Future)

```http
POST <app_webhook_url>
Content-Type: application/json
X-Signature: <HMAC-SHA256 signature>

{
  "event": "payment.completed" | "payment.failed" | "payment.refunded",
  "data": {
    "transactionId": "txn_1234567890",
    "userId": "user_xyz",
    "status": "completed",
    "amount": 100,
    "currency": "coins",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

---

## 10. Implementation Notes

### Important
1. **Always verify payment reference** before crediting coins
2. **Use idempotent transaction IDs** to prevent double-crediting
3. **Log all payment attempts** for audit trail
4. **Implement retry logic** for external API calls
5. **Cache payment methods** to reduce database queries
6. **Set timeout** for external API calls (30 seconds recommended)

### Currency Conversion
- Store all amounts in smallest unit (kobo, cents, paise)
- Multiply by 100 for Paystack API calls
- Display with proper decimal places to user

### Security
- Never log full payment details
- Encrypt sensitive payment data
- Use HTTPS only
- Rotate API keys regularly
- Implement fraud detection

---

## 11. Testing with Sandbox

### Paystack Sandbox
```
Public Key: pk_test_...
Secret Key: sk_test_...
Test Reference: Can use any reference_YYYMMDD pattern
```

### Google Play Sandbox
```
Package: com.android.vending (staging)
Product ID: com.flip.coins.pack_test
Purchase Token: Staging token format
```

### App Store Sandbox
```
Environment: sandbox
Bundle ID: com.flip.app
Product ID: com.flip.coins.pack_test
```

---

## 12. Deployment Checklist

- [ ] All payment endpoints implemented
- [ ] Database schema created for transactions
- [ ] Authentication middleware working
- [ ] Error handling implemented
- [ ] Logging configured
- [ ] Rate limiting enabled
- [ ] Paystack credentials configured
- [ ] Google Play credentials configured
- [ ] App Store credentials configured
- [ ] Webhook endpoints (if using)
- [ ] Payment audit logging
- [ ] SSL/TLS certificates valid
- [ ] CORS configured
- [ ] Load testing completed
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Team trained on payment handling

---

## Contact & Support

For payment-related issues:
1. Check transaction logs first
2. Verify payment provider status
3. Check rate limiting
4. Ensure authentication token is valid
5. Review error response details

Payment processing team: [support contact]

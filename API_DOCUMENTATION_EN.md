# Archie API Documentation

## Overview

Archie is a product safety analysis application that uses AI to analyze product images and provide safety information for children and pets.

**Base URL:** `https://be.archieml.com` (Production) | `http://localhost:4000` (Development)

**Authentication:** Firebase ID Token (Bearer Token)

---

## Table of Contents

1. [Authentication Flow](#1-authentication-flow)
2. [Image Analysis Flow](#2-image-analysis-flow)
3. [History Management](#3-history-management)
4. [Sharing Flow](#4-sharing-flow)
5. [Data Models](#5-data-models)

---

## 1. Authentication Flow

### 1.1 Login Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Mobile App    │     │  Firebase Auth  │     │  Archie API   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  1. Sign in with      │                       │
         │     Google/Apple      │                       │
         │──────────────────────>│                       │
         │                       │                       │
         │  2. Return ID Token   │                       │
         │<──────────────────────│                       │
         │                       │                       │
         │  3. POST /api/auth/login                      │
         │───────────────────────────────────────────────>
         │                       │                       │
         │  4. Verify token & return user info           │
         │<───────────────────────────────────────────────
         │                       │                       │
         │  5. Store token locally                       │
         │                       │                       │
```

#### POST `/api/auth/login`

Authenticate user with Firebase ID token.

**Request:**

```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIs..."
}
```

**Response (200 OK):**

```json
{
  "status": "success",
  "token": "eyJhbGciOiJSUzI1NiIs...",
  "user": {
    "uid": "abc123xyz",
    "email": "user@example.com",
    "displayName": "John Doe",
    "photoURL": "https://..."
  }
}
```

**Error Response (401):**

```json
{
  "statusCode": 401,
  "message": "Invalid or expired token"
}
```

### 1.2 Get Current User

#### GET `/api/auth/me`

Get current authenticated user info.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Response (200 OK):**

```json
{
  "user": {
    "uid": "abc123xyz",
    "email": "user@example.com",
    "displayName": "John Doe",
    "photoURL": "https://..."
  }
}
```

**Response (Unauthorized):**

```json
{
  "user": null
}
```

### 1.3 Get User Profile

#### GET `/api/auth/profile`

Get detailed user profile from Firestore.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Response (200 OK):**

```json
{
  "user": {
    "uid": "abc123xyz",
    "email": "user@example.com",
    "displayName": "John Doe",
    "photoURL": "https://...",
    "createdAt": "2024-01-15T10:30:00.000Z"
  }
}
```

### 1.4 Update User Profile

#### PATCH `/api/auth/profile`

Update user display name.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Request:**

```json
{
  "displayName": "New Name"
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "Profile updated successfully",
  "user": {
    "uid": "abc123xyz",
    "displayName": "New Name"
  }
}
```

### 1.5 Logout

#### POST `/api/auth/logout`

Logout user (client-side token cleanup).

**Response (200 OK):**

```json
{
  "status": "success",
  "message": "Logged out successfully"
}
```

---

## 2. Image Analysis Flow

### 2.1 Complete Analysis Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Mobile App    │     │  Archie API   │     │   Gemini AI     │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  1. Capture/Select    │                       │
         │     Image             │                       │
         │                       │                       │
         │  2. Convert to Base64 │                       │
         │     (no data: prefix) │                       │
         │                       │                       │
         │  3. POST /api/analyze │                       │
         │───────────────────────>                       │
         │                       │                       │
         │                       │  4. Send to Gemini    │
         │                       │──────────────────────>│
         │                       │                       │
         │                       │  5. AI Analysis       │
         │                       │<──────────────────────│
         │                       │                       │
         │  6. Return analysis   │                       │
         │<───────────────────────                       │
         │                       │                       │
         │  7. Display results   │                       │
         │                       │                       │
         │  8. Upload image to   │                       │
         │     Firebase Storage  │                       │
         │     (background)      │                       │
         │                       │                       │
         │  9. Save to history   │                       │
         │     (if logged in)    │                       │
         │───────────────────────>                       │
         │                       │                       │
```

#### POST `/api/analyze`

Analyze product image for safety.

**Request:**

```json
{
  "imageBase64": "/9j/4AAQSkZJRg...",
  "options": {
    "includeDogs": true,
    "includeCats": true,
    "includeChildren": true
  }
}
```

| Field                     | Type    | Required | Description                                                                  |
| ------------------------- | ------- | -------- | ---------------------------------------------------------------------------- |
| `imageBase64`             | string  | Yes      | Base64 encoded image (JPEG/PNG), **without** `data:image/...;base64,` prefix |
| `options.includeDogs`     | boolean | No       | Include dog safety analysis (default: true)                                  |
| `options.includeCats`     | boolean | No       | Include cat safety analysis (default: true)                                  |
| `options.includeChildren` | boolean | No       | Include children safety analysis (default: true)                             |

**Response (200 OK):**

```json
{
  "id": "analysis_1701234567890_abc123",
  "name": "Johnson's Baby Shampoo",
  "image": "",
  "safetyScore": {
    "overall": 85,
    "maxScore": 100
  },
  "category": "Baby Care",
  "recognitionStatus": "success",
  "analysis": {
    "kidSafety": {
      "status": "safe",
      "score": 90,
      "benefits": [
        "Tear-free formula",
        "Dermatologist tested",
        "No harsh chemicals"
      ],
      "concerns": ["Contains fragrance"],
      "narrative": "This baby shampoo is generally safe for children..."
    },
    "petSafety": {
      "dogs": {
        "status": "warning",
        "score": 60,
        "warnings": ["Not formulated for pet skin pH"],
        "pros": ["Mild formula"],
        "cons": ["May cause dry skin in dogs"],
        "narrative": "While gentle, this product is not ideal for dogs...",
        "details": [
          {
            "severity": "medium",
            "warning": "pH Level Mismatch",
            "reason": "Human shampoos have different pH than dog skin requires"
          }
        ]
      },
      "cats": {
        "status": "warning",
        "score": 50,
        "warnings": ["Contains ingredients potentially irritating to cats"],
        "pros": [],
        "cons": ["May cause skin irritation"],
        "narrative": "Not recommended for cats..."
      }
    },
    "hygiene": {
      "recommendations": ["Store in cool, dry place", "Check expiration date"],
      "warnings": []
    },
    "generalSafety": {
      "pros": [
        {
          "id": "pro_1",
          "label": "Hypoallergenic",
          "severity": "positive",
          "category": "ingredients"
        }
      ],
      "cons": [
        {
          "id": "con_1",
          "label": "Contains fragrance",
          "severity": "low",
          "category": "ingredients"
        }
      ]
    },
    "recalls": []
  },
  "petSafetyOptions": {
    "includeDogs": true,
    "includeCats": true,
    "includeChildren": true
  },
  "analysisMetadata": {
    "scanDuration": 2.5,
    "canonicalCategory": "personal_care",
    "rulesTriggered": ["baby_product_boost"],
    "childSafetyScore": 90,
    "dogSafetyScore": 60,
    "catSafetyScore": 50,
    "modelConfidence": 0.95,
    "recognitionConfidence": 0.88
  }
}
```

**Error Response (400):**

```json
{
  "error": "Image is required"
}
```

**Error Response (500):**

```json
{
  "error": "Failed to analyze image"
}
```

### 2.2 Image Preparation Guidelines

1. **Format:** JPEG or PNG recommended
2. **Size:** Optimize to max 1600x1600 pixels, max 2MB
3. **Encoding:** Pure Base64 without data URL prefix
4. **Quality:** 0.8-0.9 JPEG quality for best balance

**Example (JavaScript):**

```javascript
async function prepareImage(file) {
  // Resize if needed
  const canvas = document.createElement("canvas");
  // ... resize logic ...

  // Convert to base64
  const base64 = canvas.toDataURL("image/jpeg", 0.9);

  // Remove data URL prefix
  return base64.split(",")[1];
}
```

---

## 3. History Management

### 3.1 History Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Mobile App    │     │  Archie API   │     │    Firestore    │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  After successful     │                       │
         │  analysis...          │                       │
         │                       │                       │
         │  POST /api/history    │                       │
         │───────────────────────>                       │
         │                       │  Save to              │
         │                       │  users/{uid}/scanHistory
         │                       │──────────────────────>│
         │                       │                       │
         │  200 OK               │                       │
         │<───────────────────────                       │
         │                       │                       │
```

### 3.2 Get History

#### GET `/api/history`

Get user's scan history.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Response (200 OK):**

```json
[
  {
    "id": "analysis_1701234567890_abc123",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "name": "Johnson's Baby Shampoo",
    "score": 85,
    "maxScore": 100,
    "preview": null,
    "imageUrl": "https://firebasestorage.googleapis.com/...",
    "labels": ["baby", "shampoo", "personal care"],
    "category": "Baby Care",
    "petSafetyOptions": {
      "includeDogs": true,
      "includeCats": true,
      "includeChildren": true
    }
  }
]
```

### 3.3 Save to History

#### POST `/api/history`

Save scan to user's history.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Request:**

```json
{
  "item": {
    "id": "analysis_1701234567890_abc123",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "name": "Johnson's Baby Shampoo",
    "score": 85,
    "maxScore": 100,
    "preview": null,
    "imageUrl": "https://firebasestorage.googleapis.com/...",
    "labels": ["baby", "shampoo"],
    "category": "Baby Care",
    "petSafetyOptions": {
      "includeDogs": true,
      "includeCats": true,
      "includeChildren": true
    },
    "fullAnalysis": {
      /* Full ProductAnalysis object */
    }
  }
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "History saved"
}
```

### 3.4 Delete from History

#### DELETE `/api/history?id={itemId}`

Delete scan from user's history.

**Headers:**

```
Authorization: Bearer <firebase_id_token>
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Analysis ID to delete |

**Response (200 OK):**

```json
{
  "success": true,
  "message": "History deleted"
}
```

---

## 4. Sharing Flow

### 4.1 Share Flow Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Mobile App    │     │  Archie API   │     │    Firestore    │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  User taps "Share"    │                       │
         │                       │                       │
         │  POST /api/share-cache│                       │
         │───────────────────────>                       │
         │                       │  Save to              │
         │                       │  publicAnalysis/{id}  │
         │                       │──────────────────────>│
         │                       │                       │
         │  200 OK               │                       │
         │<───────────────────────                       │
         │                       │                       │
         │  Generate share URL:  │                       │
         │  https://archieml.com/share/{id}          │
         │                       │                       │
         │  Share via system     │                       │
         │  share sheet          │                       │
         │                       │                       │
```

### 4.2 Cache Analysis for Sharing

#### POST `/api/share-cache`

Save analysis to public cache for sharing.

**Request:**

```json
{
  "analysis": {
    "id": "analysis_1701234567890_abc123",
    "name": "Johnson's Baby Shampoo",
    "image": "",
    "imageUrl": "https://firebasestorage.googleapis.com/...",
    "safetyScore": { "overall": 85, "maxScore": 100 },
    "category": "Baby Care",
    "analysis": {
      /* Full analysis object */
    }
  }
}
```

> **Note:** The `image` field should be empty string when sharing. Use `imageUrl` for the Firebase Storage URL.

**Response (200 OK):**

```json
{
  "success": true,
  "message": "Analysis cached for sharing"
}
```

### 4.3 Get Shared Analysis

#### GET `/api/analysis/{id}`

Get analysis by ID (for viewing shared results).

**Path Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | Yes | Analysis ID |

**Response (200 OK):**

```json
{
  "id": "analysis_1701234567890_abc123",
  "name": "Johnson's Baby Shampoo",
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "safetyScore": { "overall": 85, "maxScore": 100 },
  "category": "Baby Care",
  "analysis": {
    /* Full analysis object */
  }
}
```

**Response (404 Not Found):**

```json
{
  "statusCode": 404,
  "message": "Analysis not found"
}
```

---

## 5. Data Models

### 5.1 ProductAnalysis

Main analysis result object.

```typescript
interface ProductAnalysis {
  id: string; // Unique analysis ID
  name: string; // Product name
  image: string; // Base64 image (empty for shared)
  imageUrl?: string; // Firebase Storage URL
  safetyScore: SafetyScore;
  analysis: SafetyAnalysis;
  category: string; // Product category
  recognitionStatus?: "success" | "failed";
  petSafetyOptions?: PetSafetyOptions;
  analysisMetadata?: AnalysisMetadata;
}
```

### 5.2 SafetyScore

```typescript
interface SafetyScore {
  overall: number; // 0-100
  maxScore: number; // Always 100
}
```

### 5.3 SafetyAnalysis

```typescript
interface SafetyAnalysis {
  kidSafety: {
    status: "safe" | "warning" | "danger";
    score?: number; // 0-100
    benefits: string[];
    concerns: string[];
    narrative?: string; // AI-generated summary
  };
  petSafety: {
    dogs: PetSafetyItem;
    cats: PetSafetyItem;
  };
  hygiene: {
    recommendations: string[];
    warnings?: HygieneWarning[];
  };
  generalSafety?: {
    pros: SafetyPoint[];
    cons: SafetyPoint[];
  };
  recalls?: Recall[];
}
```

### 5.4 PetSafetyItem

```typescript
interface PetSafetyItem {
  status: "safe" | "warning" | "danger";
  score?: number; // 0-100
  warnings: string[];
  pros?: string[];
  cons?: string[];
  narrative?: string; // AI-generated summary
  details?: Array<{
    severity: "low" | "medium" | "high";
    warning: string;
    reason: string;
  }>;
}
```

### 5.5 ScanHistoryItem

```typescript
interface ScanHistoryItem {
  id: string;
  createdAt: string; // ISO 8601 format
  name: string;
  score: number;
  maxScore: number;
  preview: string | null; // Thumbnail base64
  imageUrl?: string; // Firebase Storage URL
  labels: string[];
  category?: string;
  petSafetyOptions?: PetSafetyOptions;
  analysisMetadata?: AnalysisMetadata;
  fullAnalysis?: ProductAnalysis;
}
```

### 5.6 Supporting Types

```typescript
interface SafetyPoint {
  id: string;
  label: string;
  severity: string;
  category: string;
}

interface HygieneWarning {
  id: string;
  type: string;
  message: string;
}

interface Recall {
  id: string;
  date: string;
  reason: string;
  severity: string;
  source: string;
}

interface PetSafetyOptions {
  includeDogs: boolean;
  includeCats: boolean;
  includeChildren: boolean;
}

interface AnalysisMetadata {
  scanDuration?: number;
  canonicalCategory?: string;
  rulesTriggered?: string[];
  childSafetyScore?: number;
  dogSafetyScore?: number;
  catSafetyScore?: number;
  modelConfidence?: number;
  recognitionConfidence?: number;
}
```

---

## 6. Firebase Storage

### 6.1 Image Upload

Images are uploaded directly to Firebase Storage from the client.

**Storage Path:** `analysis-images/public/{analysisId}`

**Upload Flow:**

1. After successful analysis, upload image to Firebase Storage
2. Get download URL
3. Include `imageUrl` when saving to history and share cache

### 6.2 Firebase Configuration

```javascript
// Firebase Storage bucket
const storageBucket = "safesnap-4dc22.appspot.com";

// Upload path pattern
const uploadPath = `analysis-images/public/${analysisId}`;
```

---

## 7. Error Handling

### Standard Error Response

```json
{
  "statusCode": 400,
  "message": "Error description",
  "error": "Bad Request"
}
```

### Common Error Codes

| Code | Description                             |
| ---- | --------------------------------------- |
| 400  | Bad Request - Invalid input             |
| 401  | Unauthorized - Invalid or missing token |
| 404  | Not Found - Resource doesn't exist      |
| 500  | Internal Server Error                   |

---

## 8. Rate Limiting

- **Analyze endpoint:** 10 requests per minute per user
- **Other endpoints:** 60 requests per minute per user

---

## 9. Best Practices

1. **Always validate token** before making authenticated requests
2. **Cache analysis results** locally for offline viewing
3. **Compress images** before sending to reduce latency
4. **Handle errors gracefully** with user-friendly messages
5. **Implement retry logic** for network failures
6. **Use background processing** for image upload and history sync

---

## 10. Swagger Documentation

Interactive API documentation available at:

- **Production:** https://be.archieml.com/api/docs

---

_Last Updated: December 2024_

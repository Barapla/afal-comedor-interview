# API_ENDPOINTS.md — Afal Comedor Interview

> LIVE CONTRACT: This file documents the API endpoints exposed by this project.
> It MUST be updated whenever an endpoint is created, modified, or removed.
> Read `.claude/ENGINEERING_STANDARDS.md` for the mandatory update rule.

---


## Authentication

Describe the authentication mechanism used by this API.

| Method | Header | Description |
|---|---|---|
| API Key | `X-Api-Key` | For external integrations |
| JWT Bearer | `Authorization: Bearer <token>` | For management endpoints |

---


## Endpoints

| Method | Path | Auth | Request Body | Response Body | Notes |
|---|---|---|---|---|---|
| GET | /api/v1/users | API Key | — | `{ records: [...] }` | List users |
| GET | /api/v1/users/:id | API Key | — | `{ record: {...} }` | Get user |
| POST | /api/v1/users | API Key | `{ user: {...} }` | `{ record: {...} }` | Create user |
| PUT | /api/v1/users/:id | API Key | `{ user: {...} }` | `{ record: {...} }` | Update user |
| DELETE | /api/v1/users/:id | API Key | — | `{ record: {...} }` | Delete user |
| GET | /api/v1/auth | API Key | — | `{ records: [...] }` | List auth |
| GET | /api/v1/auth/:id | API Key | — | `{ record: {...} }` | Get auth |
| POST | /api/v1/auth | API Key | `{ auth: {...} }` | `{ record: {...} }` | Create auth |
| PUT | /api/v1/auth/:id | API Key | `{ auth: {...} }` | `{ record: {...} }` | Update auth |
| DELETE | /api/v1/auth/:id | API Key | — | `{ record: {...} }` | Delete auth |

---

## Endpoint Details

### GET /api/v1/users

**Auth:** API Key

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### GET /api/v1/users/:id

**Auth:** API Key

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### POST /api/v1/users

**Auth:** API Key

#### Request Body

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| field_name | string | Yes/No | Field description |

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### PUT /api/v1/users/:id

**Auth:** API Key

#### Request Body

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| field_name | string | Yes/No | Field description |

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### DELETE /api/v1/users/:id

**Auth:** API Key

---

### GET /api/v1/auth

**Auth:** API Key

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### GET /api/v1/auth/:id

**Auth:** API Key

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### POST /api/v1/auth

**Auth:** API Key

#### Request Body

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| field_name | string | Yes/No | Field description |

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### PUT /api/v1/auth/:id

**Auth:** API Key

#### Request Body

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| field_name | string | Yes/No | Field description |

#### Response Body

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | integer | Database ID |
| created_at | datetime | ISO8601 timestamp |
| updated_at | datetime | ISO8601 timestamp |

---

### DELETE /api/v1/auth/:id

**Auth:** API Key

---


## Response Formats

### Success — Single record
```json
{ "record": { "id": 1, "..." : "..." } }
```

### Success — Collection
```json
{ "records": [ { "id": 1 }, { "id": 2 } ] }
```

### Error
```json
{ "error": { "code": "not_found", "message": "...", "details": {} } }
```

---


## Maintenance Rule

Any ticket that creates, modifies, or removes an endpoint MUST update this file before the final commit.
See ENGINEERING_STANDARDS.md — API Changes section for details.

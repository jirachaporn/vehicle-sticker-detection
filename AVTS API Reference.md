# AVTS API Reference

Formal reference for the AVTS (Automated Vehicle Tagging System) backend endpoints used by the frontend.

> **Base URL (local development)**
>
> ```
> http://localhost:8000
> ```
>
> All timestamps are returned in **ISO 8601** (e.g., `2025-10-14T09:30:00+07:00`) and are intended for **Asia/Bangkok (UTC+07:00)** unless otherwise noted.

---

## Endpoint Index

| Method | Path                                                                 | Description |
|:------:|----------------------------------------------------------------------|-------------|
| GET    | `/`                                                                  | Health check to confirm the API is up. |
| GET    | `/overview/{location_id}`                                            | Overview Page. |
| GET    | `/notifications`                                                     | List notifications (filter by location, status, pagination). |
| GET    | `/notifications/summary`                                             | Get unread counts grouped by severity for a location. |
| PATCH  | `/notifications/{notification_id}/read`                              | Mark a single notification as **read**. |
| PATCH  | `/notifications/mark-all-read`                                       | Mark **all** notifications for a location as **read**. |
| GET    | `/table/{location_id}/records`                                       | Paged table of detection records with filters/sorting. |

---

## 1) AVTS RUN API — Health Check

- ### How to call `http://localhost:8000/`

## 2) Overview Page
Path Parameters
| Name          | Type   | Required | Description               |
| ------------- | ------ | -------- | ------------------------- |
| `location_id` | string | ✅        | The target location UUID. |

- ### How to call `GET http://localhost:8000/overview/{location_id}`
#### `GET http://localhost:8000/overview/44950349-bd33-49a6-a90a-3159537d2361`

## 3) Notification Page — List
Path Parameters & Query Parameters
| Name          | Type    | Required | Default | Allowed Values         | Description              |
| ------------- | ------- | -------- | ------- | ---------------------- | ------------------------ |
| `location_id` | string  | ✅        | —       | —                      | Location UUID to filter. |
| `status`      | string  | ❌        | `new`   | `new`  `read`  `all` | Filter by read status.   |
| `limit`       | integer | ❌        | `20`    | 1–100                  | Page size.               |
| `offset`      | integer | ❌        | `0`     | 0+                     | Results offset.          |

- ### How to call `GET /notifications`
#### `GET http://localhost:8000/notifications?location_id=44950349-bd33-49a6-a90a-3159537d2361&status=all&limit=20&offset=0`

## 4) Unread Counts (by Severity) เลขที่ไอคอนกระดิ่ง
Path Parameters
| Name          | Type   | Required | Description    |
| ------------- | ------ | -------- | -------------- |
| `location_id` | string | ✅        | Location UUID. |

- ### How to call `GET /notifications/summary`
#### `GET http://localhost:8000/notifications/summary?location_id=44950349-bd33-49a6-a90a-3159537d2361`

## 5) Mark One Notification as Read
Path Parameters
| Name              | Type   | Required | Description        |
| ----------------- | ------ | -------- | ------------------ |
| `notification_id` | string | ✅        | Notification UUID. |

- ### How to call `PATCH /notifications/{notification_id}/read`
#### `PATCH http://localhost:8000/notifications/ef7cacf6-a09e-4260-94a3-984b155ea8e5/read`

## 6) Mark All Notifications as Read (by Location)
Path Parameters
| Field         | Type   | Required | Example                                  | Description                 |
| ------------- | ------ | -------- | ---------------------------------------- | --------------------------- |
| `location_id` | string | ✅        | `"44950349-bd33-49a6-a90a-3159537d2361"` | Location UUID.              |
| `type`        | string | ✅        | `"ALL"`                                  | Currently supports `"ALL"`. |

### 📤 Request Body raw (JSON)

```json
{
  "location_id": "44950349-bd33-49a6-a90a-3159537d2361",
  "type": "ALL"
}
```
- ### How to call `PATCH /notifications/mark-all-read`
#### `PATCH http://localhost:8000/notifications/mark-all-read`

## 7) Page Table — Detection Records
Path Parameters
| Name          | Type   | Required | Description    |
| ------------- | ------ | -------- | -------------- |
| `location_id` | string | ✅        | Location UUID. |

Query Parameters
| Name        | Type    | Required | Default            | Allowed Values / Format                                                         | Description                                   |
| ----------- | ------- | -------- | ------------------ | ------------------------------------------------------------------------------- | --------------------------------------------- |
| `search`    | string  | ❌        | —                  | any text                                                                        | Case-insensitive search by **license plate**. |
| `direction` | string  | ❌        | —                  | `in`  `out`                                                                    | Filter by traffic direction.                  |
| `sticker`   | boolean | ❌        | —                  | `true`  `false`                                                                | Filter by whether a sticker was detected.     |
| `sort`      | string  | ❌        | `detected_at.desc` | `field` or `field.asc` / `field.desc` (e.g., `detected_at`, `detected_at.desc`) | Sort criterion.                               |
| `page`      | integer | ❌        | `1`                | 1+                                                                              | Page number (1-based).                        |
| `page_size` | integer | ❌        | `20`               | 1–100                                                                           | Items per page.                               |

- ### How to call `GET /table/{location_id}/records`
#### `GET http://localhost:8000/table/44950349-bd33-49a6-a90a-3159537d2361/records?search=2ฒช6726&direction=in&sticker=true&sort=detected_at&page=1&page_size=20`

## 8) Save Trained Model & Create Notification
Path Parameters
| Field      | Type   | Required | Example                                  | Description                                  |
| ---------- | ------ | -------- | ---------------------------------------- | -------------------------------------------- |
| `model_id` | string | ✅        | `"78e55fae-dbde-4980-802a-483ed06c3c19"` | Model UUID ที่ต้องการบันทึกสถานะเป็น `ready` |


### 📤 Request Body raw (JSON) - Ready
```json
{
  "location_id": "44950349-bd33-49a6-a90a-3159537d2361",
  "reason": "Model training completed :)"
}
```
- ### How to call `POST /models/{model_id}/save` กรณีแจ้ง Ready
#### `POST http://localhost:8000/models/78e55fae-dbde-4980-802a-483ed06c3c19/save`
### 📤 Request Body raw (JSON) - Failed
```json
{
  "location_id": "44950349-bd33-49a6-a90a-3159537d2361",
  "reason": "There are not enough sticker images for training the model"
}
```
- ### How to call `POST /models/{model_id}/fail` กรณีแจ้ง Failed
#### `POST http://localhost:8000/models/5058d77f-7e0a-4454-a5b6-fe7d116811ab/fail`
### Notes
- จะอัปเดตในตาราง `model` เป็น `sticker_status = "ready"` และ `is_active = false` จากนั้นจะสร้างแถวในตาราง `notifications` ให้ทันที
- `"reason"` เป็นออปชัน ใช้ควบคุมข้อความใน meta.reason ของ Notification

## 9) Create Permission Notification (from `permission_log`)
Path Parameters
| `status`           | Action     | Severity   | หมายเหตุ                                                       |
| ------------------ | ---------- | ---------- | -------------------------------------------------------------- |
| `invited`          | `invited`  | `info`     | เจ้าของเชิญสมาชิก                                              |
| `updatepermission` | `accepted` | `info`     | ถ้า `by_email == member_email` (ผู้ถูกเชิญกดรับสิทธิ์เอง)      |
| `updatepermission` | `updated`  | `info`     | ถ้า `by_email != member_email` (เจ้าของ/แอดมินปรับระดับสิทธิ์) |
| `disabled`         | `revoked`  | `critical` | เพิกถอนสิทธิ์                                                  |

### 📤 Request Body raw (JSON)
```json
{
  "permission_log_id": "3e98e1b3-2de7-4825-b70c-9202efb688f3",
  "location_id": "44950349-bd33-49a6-a90a-3159537d2361"
}
```
- ### How to call `POST /notifications/permission`
#### `POST http://localhost:8000/notifications/permission`
### Notes
- `permission_log_id` (required) : อ้างอิงแถวในตาราง permission_log
- `location_id` (optional) : ใช้ตรวจสอบความถูกต้อง และดึง location_name ไปใส่ใน meta

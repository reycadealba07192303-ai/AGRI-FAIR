# AgriFair — API contract

Dalawang client ang kumakain sa iisang API: ang **web** (React, para sa seller,
admin at superadmin) at ang **mobile** (Flutter, para sa buyer). Ito ang
sanggunian nilang dalawa, para hindi na kailangang magtanong sa isa't isa.

Base URL: `/api` — halimbawa `http://localhost:8080/api`.
Kinopya ang mga halimbawa mula sa tumatakbong server, hindi hula.

---

## Balot ng sagot

Karamihan ng route ay nakabalot:

```json
{ "success": true, "message": "Products retrieved successfully", "data": { } }
```

Pero **hindi lahat** — ang `/user/me` ay ibinabalik ang dokumento mismo, walang
balot. Kaya sa mobile, tinatanggal ng `ApiClient` ang `data` kapag naroon at
ibinabalik ang buong body kapag wala.

Ang pagkabigo ay laging may mababasang `message`:

```json
{ "success": false, "message": "That name is already taken. Please choose another one." }
```

May ilang pagkabigo na may dagdag na `code` — para sa mga dapat aksyunan ng
client, hindi lang ipakita:

| `code` | Kahulugan | Dapat gawin ng client |
|---|---|---|
| `EMAIL_NOT_VERIFIED` | Hindi pa napapatunayan ang email | Dalhin sa OTP screen, magpadala ng bagong code |

> Basahin ang `code`, huwag ang pangungusap. Nagbabago ang wording; ang `code` hindi.

---

## `GET /api/products/:id`

```json
{
  "success": true,
  "message": "Product retrieved successfully",
  "data": {
    "_id": "6a89913e09aeca84016e7172",
    "name": "Premium Jasmine Rice",
    "variety": "Jasmine",
    "price": 60,
    "description": "...",
    "stock": 10,
    "lowStockThreshold": 0,
    "soldCount": 0,
    "weightTiers": [
      { "weightKg": 50, "discountPercent": 5 },
      { "weightKg": 25, "discountPercent": 2 }
    ],
    "images": ["/uploads/media/1787390813413-rice.jpg"],
    "status": "active",
    "createdBy": 6,
    "averageRating": 0,
    "reviewCount": 0,
    "createdAt": "2026-08-22T12:08:30.507Z",
    "updatedAt": "2026-08-22T12:08:30.510Z"
  }
}
```

### Bawat field

| Field | Uri | Tandaan |
|---|---|---|
| `_id` | string | Ang ObjectId. **Ito ang id sa lahat ng ibang tawag** — cart, review, order. Hindi `id`. |
| `name` | string | |
| `variety` | enum | Isa sa: `Jasmine`, `Sinandomeng`, `Brown Rice`, `Black Rice`, `Red Rice`, `Glutinous (Malagkit)`, `Other`. **Ito ang pangalan, hindi `category`** — tinatanggap pa rin ang `category` bilang query alias, pero `variety` ang laman ng sagot. |
| `price` | number | Piso kada kilo, ang batayan ng lahat ng tier. |
| `stock` | number | Bumababa kapag na-confirm ang order, hindi sa checkout. |
| `soldCount` | number | Sumusunod sa `stockDeducted`: tumataas kapag confirmed, bumabalik kapag cancelled. |
| `weightTiers` | array | `weightKg` + `discountPercent`. **Galing sa backend ang presyo ng bawat timbang — huwag nang i-compute sa app.** |
| `images` | string[] | **Server-relative** (`/uploads/...`). Kailangan ng origin sa harap — `ApiConfig.mediaUrl()` sa mobile. |
| `status` | enum | `active` o `inactive`. |
| `createdBy` | number | `userId` ng seller (hindi ObjectId). |
| `averageRating` | number | Isang desimal, galing sa Review collection. `0` kapag walang review. |
| `reviewCount` | number | |

### Presyo ayon sa timbang

```
kabuuan = price × weightKg × (1 − discountPercent / 100)
```

Nasa backend ang mga tier, kaya iisa ang sagot ng web at mobile. Dating
hardcoded sa app ang mga diskuwento — huwag nang ibalik iyon.

### Wala rito

Ipinapakita ng mobile UI ang mga badge tulad ng "Best Seller" at ang kulay ng
tag. **Wala ang mga iyon sa backend** at pandekorasyon lang sa app. Gamitin ang
`soldCount` kung kailangan ng tunay na numero.

---

## `GET /api/products`

Kaparehong hugis ng produkto, nakabalot sa listahan:

```json
{
  "success": true,
  "data": [ { } ],
  "pagination": { "total": 1, "page": 1, "limit": 10, "pages": 1 }
}
```

Query: `?page=`, `?limit=`, `?variety=` (o `?category=`), `?status=`, `?search=`.

---

## Auth

| Route | Katawan | Ibinabalik |
|---|---|---|
| `POST /auth/register` | `name`, `email`, `password`, `role` | `user` + `verificationMethod` |
| `POST /auth/login` | `email`, `password` | `token`, `firebaseIdToken`, `user` |
| `POST /auth/verify-email-otp` | `email`, `code` | `message` |
| `POST /auth/resend-verification` | `email` | `message` |
| `POST /auth/forgot-password` | `email` | `message` |
| `POST /auth/verify-reset-otp` | `email`, `code` | `resetToken` |
| `POST /auth/reset-password` | `resetToken`, `newPassword` | `message` |
| `PUT /user/reset-password` | `currentPassword`, `newPassword` | `message` (kailangan ng auth) |

### Token

Ang backend ay nag-iisyu ng **sariling JWT** (`token`) at nagpapasa rin ng
`firebaseIdToken`. **Ang backend JWT ang itago at ipadala** bilang
`Authorization: Bearer` — iyon ang tinitingnan ng lahat ng route. Ang Firebase
ay para lang sa password.

### Sino ang nagbibigay ng code, sino ang link

Nakabatay sa `x-client` header, at **link ang default**:

| Client | `verificationMethod` |
|---|---|
| `x-client: mobile` | `otp` — 6 na digit sa email, dala ng nodemailer |
| lahat ng iba (web) | `link` — Firebase verification link |

Ipinapadala ito ng `ApiClient` ng mobile. Hindi kailangang gumawa ng anuman ang
web — tama na ang default nito.

### Role sa pag-register

Ang `allowedSelfRoles` ay `buyer`, `seller`, `superadmin`, at **`seller` ang
babagsakan kapag walang ipinasa**. Ang seller ay nagiging `pending` at
naghihintay ng approval ng Super Admin bago makapasok.

> Kaya **kailangang magpadala ng `role: 'buyer'` ang mobile.** Kung hindi,
> bawat signup sa cellphone ay magiging naka-lock na seller account.

### Bago makapasok

- Kailangang **verified na ang email** — lahat ng role, kasama ang buyer.
- Ang `seller` ay kailangang **`active`**, hindi `pending`.
- Ang `suspended` ay tinatanggihan.

---

## Natatangi ang pangalan at email

Pareho itong sinusuri sa pag-register at sa `PUT /user/edit`. Ang pangalan ay
hindi apektado ng laki ng letra at ng dami ng espasyo — iisa ang
`"Reyca De Alba"`, `"reyca de alba"`, at `"reyca  de  alba"`.

Isinasagot ang `409` kapag may kaagaw.

---

## Rate limit

| Uri | Bilang | Saklaw |
|---|---|---|
| Paghingi ng code | 5 / 15 min | `/auth/forgot-password`, `/auth/resend-verification` |
| Pagsagot ng code | 20 / 15 min | `/auth/verify-*`, `/auth/reset-password` |
| Palit ng password | 5 / 15 min | `/user/reset-password` |

Hiwalay ang paghingi at pagsagot. Noong iisa ang budget nila, ang isang normal
na flow — humingi, mali ang type, i-type ulit, tapusin — ay naubusan sa
kalagitnaan, at hindi na maabot ang attempt counter ng code.

Ang `429` ay JSON, kaya nababasa ng client ang dahilan:

```json
{ "success": false, "message": "Too many codes requested. Wait a few minutes and try again." }
```

---

## Iba pang buyer route

| Route | Layunin |
|---|---|
| `GET /cart`, `POST /cart/items`, `PUT /cart/items/:productId`, `DELETE /cart/items/:productId` | Cart |
| `POST /cart/checkout` | Gumagawa ng order |
| `GET /buyer/orders`, `GET /buyer/orders/:groupId`, `POST /buyer/orders/:groupId/cancel` | Order ng buyer |
| `GET /reviews/product/:productId`, `POST /reviews` | Review |
| `GET /notifications`, `PUT /notifications/:id/read`, `PUT /notifications/read-all` | Abiso |
| `GET /chat/conversations`, `GET /chat/messages/:conversationId`, `POST /chat/send` | Chat |
| `GET /user/me`, `PUT /user/edit` | Profile |

# Catalog

A small Flutter catalog that signs in with [DummyJSON](https://dummyjson.com) and browses products.

Demo account: `emilys` / `emilyspass`

## Run

```bash
flutter pub get
flutter run
```

## Architecture

The app is split by feature, with a thin `core` layer for networking, secure storage, and routing.

```
lib/
  core/          Dio client, token storage, router
  features/auth/ login and session
  features/products/ list, pagination, details
```

Each feature keeps three layers:

- **domain** — plain models (`AuthUser`, `Product`)
- **data** — repositories that call DummyJSON and map JSON
- **presentation** — screens and Riverpod notifiers

Riverpod is the state management choice because the session and the product list are shared, async, and need explicit loading and error states. `AuthController` restores a saved session on startup and drives navigation. `ProductsController` owns the first page, refresh, and the next page. Screens only render that state.

`go_router` redirects to `/login` until the session is restored or the user signs in, then to `/products`. Tapping a product opens `/products/:id` with the already loaded product. Opening that route without a product fetches `GET /products/:id`.

## API

| Action | Request |
| --- | --- |
| Sign in | `POST /auth/login` |
| Check session, load profile | `GET /auth/me` |
| Renew session | `POST /auth/refresh` |
| Product list | `GET /products?limit=10&skip={offset}` |
| Product details | `GET /products/:id` |

The access and refresh tokens from login are written with `flutter_secure_storage` (iOS Keychain, Android Keystore). A Dio interceptor attaches the access token as `Authorization: Bearer …` on later requests. Signing out deletes both tokens.

On launch, a saved session is checked with `GET /auth/me`, which also restores the user's name. If the server rejects the access token, the app calls `POST /auth/refresh` once and checks again; if that is rejected too, the tokens are deleted and the login screen is shown. If the server cannot be reached, the tokens are kept and the user stays signed in without profile details. The token is never decoded locally, so expiry is always decided by the server. The product endpoints are public and accept requests with any token, so an expired token does not affect browsing.

The list handles four states: loading, error with retry, an empty catalog, and the product list. Pull-to-refresh reloads the first page. Scrolling near the bottom requests the next page until `products.length` reaches `total`. A failed next page keeps the products already shown and offers retry. A next-page response is ignored if a refresh started after it was requested, and the footer spinner is still cleared so pagination keeps working.

## Tests

```bash
flutter test
```

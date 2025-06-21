# Blog Application Development Plan

## Summary of Requirements:

*   **Application Type**: Blog
*   **Backend**: Dart with Shelf
*   **Frontend**: Plain HTML/CSS/JavaScript with Server-Side Rendering (SSR) or templating via Shelf.
*   **Database**: PostgreSQL
*   **Features**:
    *   Login/Registration (Email/Password authentication)
    *   User Roles: Admin and Regular User
    *   Blog Content: Markdown support for posts, categories, comments section, admin panel for creating/editing posts.
    *   Design: Clean, minimalist, responsive.

## Detailed Plan:

### 1. Database Schema Design

We'll need tables for `users`, `posts`, `categories`, and `comments`.

```mermaid
erDiagram
    USERS ||--o{ POSTS : "creates"
    USERS ||--o{ COMMENTS : "writes"
    POSTS ||--o{ CATEGORIES : "has"
    POSTS ||--o{ COMMENTS : "receives"

    USERS {
        INTEGER id PK
        VARCHAR email UNIQUE
        VARCHAR password_hash
        VARCHAR username UNIQUE
        VARCHAR role ENUM("admin", "user")
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    POSTS {
        INTEGER id PK
        INTEGER user_id FK "REFERENCES USERS(id)"
        VARCHAR title
        TEXT content_markdown
        TEXT content_html
        VARCHAR slug UNIQUE
        BOOLEAN published
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    CATEGORIES {
        INTEGER id PK
        VARCHAR name UNIQUE
        VARCHAR slug UNIQUE
    }

    POST_CATEGORIES {
        INTEGER post_id FK "REFERENCES POSTS(id)"
        INTEGER category_id FK "REFERENCES CATEGORIES(id)"
        PK (post_id, category_id)
    }

    COMMENTS {
        INTEGER id PK
        INTEGER post_id FK "REFERENCES POSTS(id)"
        INTEGER user_id FK "REFERENCES USERS(id)"
        TEXT content
        TIMESTAMP created_at
    }
```

### 2. Backend Development (Dart/Shelf)

The Dart backend will handle API requests, database interactions, and server-side rendering of HTML.

#### 2.1. Project Structure (Proposed Additions)

```
personal_blog/
├── bin/
│   └── server.dart             # Main server entry point
│   └── handlers/               # API handlers (auth, posts, comments)
│       ├── auth_handler.dart
│       ├── post_handler.dart
│       └── comment_handler.dart
│   └── services/               # Business logic and database interactions
│       ├── user_service.dart
│       ├── post_service.dart
│       └── comment_service.dart
│   └── models/                 # Data models (User, Post, Category, Comment)
│       ├── user.dart
│       ├── post.dart
│       ├── category.dart
│       └── comment.dart
│   └── utils/                  # Utility functions (password hashing, JWT)
│       └── auth_utils.dart
│       └── db_utils.dart
├── web/
│   ├── public/                 # Static assets (CSS, JS, images)
│   │   ├── output.css
│   │   └── app.js
│   ├── templates/              # HTML templates for SSR
│   │   ├── layout.html
│   │   ├── index.html
│   │   ├── login.html
│   │   ├── register.html
│   │   ├── post_detail.html
│   │   └── admin/
│   │       ├── dashboard.html
│   │       └── post_editor.html
│   └── index.html              # Main entry point (will be replaced by SSR)
├── pubspec.yaml
├── Dockerfile
├── docker-compose.yml
└── ...
```

#### 2.2. API Endpoints

```mermaid
graph TD
    A[Client Request] --> B{Shelf Router}

    subgraph Authentication
        B -- /api/register --> C[Register User]
        B -- /api/login --> D[Login User]
        C --> E[UserService.register]
        D --> F[UserService.login]
        E -- Save to DB --> G[PostgreSQL]
        F -- Verify from DB --> G
        F -- Generate JWT --> H[AuthUtils]
        H --> I[Return Token]
    end

    subgraph Blog Posts
        B -- /api/posts (GET) --> J[List Posts]
        B -- /api/posts/:slug (GET) --> K[Get Single Post]
        B -- /api/admin/posts (POST) --> L[Create Post (Admin)]
        B -- /api/admin/posts/:id (PUT) --> M[Update Post (Admin)]
        B -- /api/admin/posts/:id (DELETE) --> N[Delete Post (Admin)]
        L,M,N --> O[PostService]
        O -- Interact with DB --> G
    end

    subgraph Comments
        B -- /api/posts/:id/comments (GET) --> P[List Comments]
        B -- /api/posts/:id/comments (POST) --> Q[Add Comment (Auth User)]
        P,Q --> R[CommentService]
        R -- Interact with DB --> G
    end

    subgraph Categories
        B -- /api/categories (GET) --> S[List Categories]
        B -- /api/admin/categories (POST) --> T[Create Category (Admin)]
        S,T --> U[CategoryService]
        U -- Interact with DB --> G
    end

    subgraph Server-Side Rendering
        B -- / --> V[Render Home Page]
        B -- /login --> W[Render Login Page]
        B -- /register --> X[Render Register Page]
        B -- /blog/:slug --> Y[Render Post Detail Page]
        B -- /admin --> Z[Render Admin Dashboard]
        V,W,X,Y,Z --> AA[HTML Templating]
        AA -- Fetch Data --> G
    end
```

#### 2.3. Key Backend Libraries (to be added to `pubspec.yaml`)

*   `shelf_router`: For routing API requests.
*   `postgres`: For PostgreSQL database interaction.
*   `argon2`: For secure password hashing.
*   `jaguar_jwt` or similar: For JSON Web Token (JWT) authentication.
*   `markdown`: For converting Markdown content to HTML.
*   `path`: For path manipulation (e.g., finding template files).
*   `mustache_template` or similar: For server-side HTML templating.

### 3. Frontend Development (HTML/CSS/JS)

The frontend will be rendered by the Dart server using HTML templates. Tailwind CSS will be used for styling. Minimal JavaScript will be used for client-side interactions (e.g., form submissions, dynamic content loading if needed).

#### 3.1. Pages/Views

*   **Public Views**:
    *   Home Page (`/`): Lists recent blog posts.
    *   Blog Post Detail Page (`/blog/:slug`): Displays a single post, comments, and comment submission form.
    *   Login Page (`/login`): User login form.
    *   Registration Page (`/register`): User registration form.
*   **Admin Views (Protected)**:
    *   Admin Dashboard (`/admin`): Overview of posts, comments, users.
    *   Post Editor (`/admin/posts/new` or `/admin/posts/:id/edit`): Form for creating/editing blog posts with Markdown input.
    *   Category Management (`/admin/categories`): List and manage categories.

#### 3.2. Styling

*   Continue using Tailwind CSS. Ensure `tailwind.config.js` is set up correctly and `output.css` is generated.

#### 3.3. Client-Side JavaScript

*   Handle form submissions (login, register, comment submission, post creation/editing) via `fetch` API calls to the Dart backend.
*   Potentially use a simple client-side Markdown renderer for preview in the admin panel, though the primary conversion will be server-side.

### 4. Docker Integration

The existing `Dockerfile` and `docker-compose.yml` will need to be updated to include PostgreSQL and potentially a reverse proxy if needed.

```yaml
# docker-compose.yml (example additions)
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://user:password@db:5432/blog_db
    depends_on:
      - db
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: blog_db
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
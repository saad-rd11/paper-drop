# Paper Drop

An AI-powered study assistant mobile app that helps students chat with their PDFs and generate practice papers.

[![Flutter Version](https://img.shields.io/badge/Flutter-3.11+-blue.svg)](https://flutter.dev)
[![Dart SDK](https://img.shields.io/badge/Dart-%5E3.11.0-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

Paper Drop is a Flutter mobile application designed to revolutionize how students study. Upload your PDF study materials and past examination papers, then:

- **Chat with your documents** using AI-powered Retrieval-Augmented Generation (RAG)
- **Generate custom practice exams** based on past paper patterns
- **Organize materials** in workspaces for different subjects

## Features

### Workspace Management
- Create, rename, and organize study workspaces
- Grid and list view options with search
- Track statistics across workspaces

### Document Upload & Processing
- Upload PDF files from your device
- Automatic text extraction and processing
- Mark documents as "past papers" or "study material"
- In-app PDF viewer
- Real-time processing status tracking

### AI-Powered Chat (RAG)
- **Context-aware Q&A** about your uploaded documents
- **Source citations** with page references [Page X]
- **Multi-turn conversations** with automatic context management
- **Query rewriting** for follow-up questions
- Streaming responses for real-time feedback

### Past Paper Agent
- **Analyze** past papers to extract patterns, topics, and difficulty distribution
- **Generate** original practice papers matching the structure and style of past exams
- Custom exams based on your uploaded study materials

## Tech Stack

### Frontend (Flutter)
| Component | Technology |
|-----------|------------|
| Framework | Flutter (Dart SDK ^3.11.0) |
| State Management | [Riverpod](https://riverpod.dev) |
| Backend | [Supabase](https://supabase.com) |
| Navigation | [Go Router](https://pub.dev/packages/go_router) |
| PDF Viewing | [Flutter PDFView](https://pub.dev/packages/flutter_pdfview) |

### Backend (Python)
| Component | Technology |
|-----------|------------|
| Framework | [FastAPI](https://fastapi.tiangolo.com) |
| PDF Processing | [PyMuPDF](https://pymupdf.readthedocs.io) |
| AI/LLM | [Google Gemini](https://ai.google.dev) |
| Database | [Supabase](https://supabase.com) |
| Vector Search | [pgvector](https://github.com/pgvector/pgvector) |

## Architecture

```
┌────────────────────────────────────────────┐
│              Flutter Mobile App            │
│                                            │
│   Workspaces ── Documents ── Chat ── Agent │
└─────────────┬──────────────────────────────┘
              │
              ▼
┌────────────────────────────────────────────┐
│              Supabase Platform             │
│  ┌──────────────────────────────────────┐  │
│  │ PostgreSQL + pgvector (vector DB)    │  │
│  ├──────────────────────────────────────┤  │
│  │ Storage Bucket (PDFs)                │  │
│  ├──────────────────────────────────────┤  │
│  │ Authentication (Email/Password)      │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────┐
│           Python FastAPI Backend           │
│  • PDF processing & text extraction        │
│  • Vector embeddings (3072-dim)            │
│  • RAG chat with context window management │
│  • Past paper analysis & generation        │
└────────────────────────────────────────────┘
```

## Project Structure

```
paper-drop/
├── app/                          # Flutter application
│   ├── lib/
│   │   ├── main.dart             # Entry point
│   │   ├── config/constants.dart # Configuration
│   │   ├── models/               # Data classes
│   │   ├── providers/            # Riverpod providers
│   │   ├── screens/              # UI screens
│   │   ├── services/             # API services
│   │   └── widgets/              # UI components
│   └── pubspec.yaml
│
├── server/                       # Python FastAPI backend
│   ├── main.py                   # FastAPI app
│   ├── routers/                  # API endpoints
│   ├── services/                 # Business logic
│   └── requirements.txt
│
├── supabase/
│   └── schema.sql                # Database migrations
│
└── README.md
```

## Getting Started

### Prerequisites
- Flutter SDK (^3.11.0)
- Dart SDK
- Python 3.9+ (for backend)
- Supabase account
- Google AI Studio API key

### 1. Clone the Repository

```bash
git clone https://github.com/saad-rd11/paper-drop.git
cd paper-drop
```

### 2. Setup Flutter App

```bash
cd app

# Install dependencies
flutter pub get

# Configure Supabase
cp lib/config/constants.dart lib/config/constants.dart.example
# Edit constants.dart with your Supabase credentials
```

**Configure Supabase credentials** in `app/lib/config/constants.dart`:

```dart
class AppConstants {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String backendUrl = 'http://localhost:8000';
}
```

### 3. Setup Python Backend

```bash
cd ../server

# Create virtual environment
python -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GEMINI_API_KEY="your-gemini-api-key"
export SUPABASE_URL="your-supabase-url"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

### 4. Setup Supabase Database

1. Create a new Supabase project
2. Enable the **pgvector** extension
3. Run the migration:
   ```bash
   psql -h YOUR_DB_HOST -U postgres -d postgres -f supabase/schema.sql
   ```
4. Create a storage bucket named `pdfs`
5. Configure Row Level Security (RLS) policies

### 5. Run the Application

**Terminal 1 - Start the Python backend:**
```bash
cd server
source venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Terminal 2 - Run Flutter app:**
```bash
cd app
flutter run
```

## Configuration

### Supabase Environment Variables (Backend)

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (not anon key) |
| `GEMINI_API_KEY` | Google AI Studio API key |

### Flutter Configuration

Edit `app/lib/config/constants.dart`:

```dart
class AppConstants {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';
  static const String backendUrl = 'http://your-backend-url:8000';
  static const String storageBucket = 'pdfs';
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/process-pdf` | POST | Extract, chunk, and embed PDF |
| `/chat` | POST | RAG chat (non-streaming) |
| `/chat/stream` | GET | Streaming chat (SSE) |
| `/agent/analyze` | POST | Analyze past papers |
| `/agent/generate` | POST | Generate practice paper |

## Context Engineering

The RAG system uses a sophisticated 5-layer context window:

```
┌─────────────────────────────────────────┐
│  Layer 1: System Prompt      (~200 tok) │
│  Layer 2: Conversation Summary(~300 tok)│
│  Layer 3: Recent Messages   (~1500 tok) │
│  Layer 4: Retrieved Chunks  (~2500 tok) │
│  Layer 5: Current Question     (~50 tok)│
└─────────────────────────────────────────┘
```

## Database Schema

### Tables
- **workspaces** - Study workspaces with metadata
- **documents** - PDF documents with processing status
- **document_chunks** - Text chunks with 3072-dim embeddings
- **chat_messages** - Conversation history with source citations
- **generated_papers** - AI-generated practice exams

### Vector Search
- Uses pgvector extension with HNSW index
- 3072-dimensional embeddings from Gemini
- Similarity search via `match_chunks()` RPC function

## Screenshots

*(Screenshots to be added)*

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Supabase](https://supabase.com) for the backend infrastructure
- [Google Gemini](https://ai.google.dev) for the AI capabilities
- [Flutter](https://flutter.dev) for the cross-platform framework
- [FastAPI](https://fastapi.tiangolo.com) for the Python backend

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/saad-rd11/paper-drop/issues) page.

---

**Made with ❤️ for students everywhere**

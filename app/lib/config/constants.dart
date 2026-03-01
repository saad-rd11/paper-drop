class AppConstants {
  // -- Supabase --
  // Replace with your Supabase project values
  static const supabaseUrl = 'https://pjfjdiivaulijntcujoa.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqZmpkaWl2YXVsaWpudGN1am9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDA0MTcsImV4cCI6MjA4Nzg3NjQxN30.JJb9-mnov2Z5eqmdS2V4Rj-cm_64ENroZOXuZwAxVkk';
  // -- Python Backend --
  // Use 10.0.2.2 when running on Android emulator (maps to host localhost)
  static const backendUrl = 'http://localhost:8000';

  // -- Storage --
  static const pdfBucket = 'pdfs';

  // -- RAG --
  static const maxChunksPerQuery = 5;
  static const recentMessageWindow = 6;
}

class AppConstants {
  // -- Supabase --
  // Replace with your Supabase project values
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'YOUR_ANON_KEY';

  // -- Python Backend --
  // Use 10.0.2.2 when running on Android emulator (maps to host localhost)
  static const backendUrl = 'http://10.0.2.2:8000';

  // -- Storage --
  static const pdfBucket = 'pdfs';

  // -- RAG --
  static const maxChunksPerQuery = 5;
  static const recentMessageWindow = 6;
}

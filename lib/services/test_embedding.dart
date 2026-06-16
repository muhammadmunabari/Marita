import 'package:firebase_ai/firebase_ai.dart';

void main() {
  final vertexAI = FirebaseAI.vertexAI(location: 'us-central1');
  
  // Let's see if we can do:
  // final embeddingModel = vertexAI.embeddingModel(model: 'text-embedding-004');
  // or
  // final generativeModel = vertexAI.generativeModel(model: 'text-embedding-004');
}

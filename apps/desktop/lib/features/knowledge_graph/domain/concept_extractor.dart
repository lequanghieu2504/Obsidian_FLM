import 'subject_record.dart';

/// One concept the graph can recognise, plus the keywords/phrases that
/// count as a mention of it. Matching is case-insensitive; a keyword only
/// needs word boundaries on the side(s) that actually start/end with a word
/// character, so both plain words ("Python") and symbol-heavy tokens
/// ("C++", ".NET") work with the same matcher.
class ConceptDefinition {
  const ConceptDefinition(this.label, this.keywords);

  /// Canonical label shown on the node (e.g. `"OOP"`, `"Spring Boot"`).
  final String label;

  /// Every phrasing that should count as this subject "having" the concept.
  final List<String> keywords;
}

/// One concept found in a subject's text, and where it was found.
class ConceptMatch {
  const ConceptMatch({required this.label, required this.sources});

  final String label;

  /// Where the keyword turned up: `"Mô tả"` for the syllabus description,
  /// or a CLO code (`"CLO1"`, `"CLO2"`, ...) for a learning outcome. A
  /// concept can come from more than one source.
  final List<String> sources;
}

/// Finds which of [_dictionary]'s concepts a subject's free-text fields
/// actually mention.
///
/// There is no structured "concepts" field anywhere in the FLM export —
/// only free-text `Description` and CLO detail strings (see
/// `domain/subject_record.dart`). This does the same kind of job
/// `domain/prerequisite_parser.dart` used to do for prerequisite codes:
/// scan raw text with a fixed, hand-curated pattern list rather than
/// anything that needs training data or network access, so it stays a
/// plain, offline, on-device Dart function.
///
/// This is deliberately a *keyword* matcher, not real NLP: it will miss
/// concepts phrased in ways the dictionary doesn't cover, and — because
/// several of these are also ordinary English words ("tree", "queue",
/// "stack") — it can occasionally match a word used in its everyday sense
/// rather than the CS one. That trade-off is fine here: every source text
/// is an academic syllabus description or learning outcome, not general
/// prose, so those words are already CS terms costume-as-nothing-else in
/// context. Extend [_dictionary] as more concepts turn out to matter.
abstract class ConceptExtractor {
  static const List<ConceptDefinition> _dictionary = [
    // Programming languages
    ConceptDefinition('Java', ['java']),
    ConceptDefinition('Python', ['python']),
    ConceptDefinition('C', ['c programming', 'c language']),
    ConceptDefinition('C++', ['c++']),
    ConceptDefinition('C#', ['c#', 'c sharp']),
    ConceptDefinition('JavaScript', ['javascript', 'js']),
    ConceptDefinition('TypeScript', ['typescript']),
    ConceptDefinition('Kotlin', ['kotlin']),
    ConceptDefinition('Swift', ['swift']),
    ConceptDefinition('PHP', ['php']),
    ConceptDefinition('Dart', ['dart language', 'dart programming', 'flutter/dart']),
    ConceptDefinition('SQL', ['sql']),
    ConceptDefinition('R', ['r programming', 'r language']),

    // Programming paradigms & CS fundamentals
    ConceptDefinition('OOP', ['object-oriented', 'object oriented', 'oop']),
    ConceptDefinition('Functional Programming', ['functional programming']),
    ConceptDefinition('Data Structures', ['data structure']),
    ConceptDefinition('Algorithms', ['algorithm']),
    ConceptDefinition('Recursion', ['recursion', 'recursive']),
    ConceptDefinition('Sorting', ['sorting', 'sort algorithm', 'quicksort', 'merge sort', 'bubble sort']),
    ConceptDefinition('Searching', ['searching algorithm', 'binary search']),
    ConceptDefinition('Linked List', ['linked list']),
    ConceptDefinition('Stack', ['stack']),
    ConceptDefinition('Queue', ['queue']),
    ConceptDefinition('Tree', ['binary tree', 'binary search tree', ' bst ', 'avl tree']),
    ConceptDefinition('Graph', ['graph traversal', 'directed graph', 'undirected graph', 'graph theory']),
    ConceptDefinition('Hashing', ['hashing', 'hash table', 'hash function']),
    ConceptDefinition('Design Pattern', ['design pattern']),
    ConceptDefinition('UML', ['uml']),

    // Databases
    ConceptDefinition('Database', ['database', 'dbms']),
    ConceptDefinition('NoSQL', ['nosql', 'mongodb']),

    // Web
    ConceptDefinition('HTML/CSS', ['html', 'css']),
    ConceptDefinition('REST API', ['rest api', 'restful']),
    ConceptDefinition('Node.js', ['node.js', 'nodejs']),
    ConceptDefinition('React', ['react.js', 'reactjs', 'react native']),
    ConceptDefinition('Angular', ['angular']),
    ConceptDefinition('Spring', ['spring boot', 'spring cloud', 'spring framework']),
    ConceptDefinition('.NET', ['.net', 'asp.net', 'dotnet']),

    // Mobile
    ConceptDefinition('Flutter', ['flutter']),
    ConceptDefinition('Android', ['android']),
    ConceptDefinition('iOS', ['ios development', 'ios app']),

    // Cloud / DevOps
    ConceptDefinition('Docker', ['docker']),
    ConceptDefinition('Kubernetes', ['kubernetes', 'k8s']),
    ConceptDefinition('Microservices', ['microservice']),
    ConceptDefinition('Cloud Computing', ['cloud computing', 'aws', 'azure', 'google cloud']),
    ConceptDefinition('Git', ['git', 'version control']),
    ConceptDefinition('CI/CD', ['ci/cd', 'continuous integration', 'continuous deployment']),

    // AI / Data
    ConceptDefinition('Machine Learning', ['machine learning']),
    ConceptDefinition('Deep Learning', ['deep learning', 'neural network']),
    ConceptDefinition('Artificial Intelligence', ['artificial intelligence']),
    ConceptDefinition('Data Mining', ['data mining']),
    ConceptDefinition('Big Data', ['big data']),
    ConceptDefinition('Data Analysis', ['data analysis', 'data analytics']),

    // Networking & security
    ConceptDefinition('Computer Networks', ['computer network', 'tcp/ip', 'networking']),
    ConceptDefinition('Cybersecurity', ['cybersecurity', 'cyber security', 'information security']),
    ConceptDefinition('Cryptography', ['cryptography', 'encryption']),

    // Software engineering process
    ConceptDefinition('Testing', ['unit test', 'software testing', 'test case']),
    ConceptDefinition('Agile/Scrum', ['agile', 'scrum']),
    ConceptDefinition('Software Architecture', ['software architecture']),
    ConceptDefinition('Requirements Analysis', ['requirement analysis', 'requirements analysis']),

    // Business / soft-skill subjects (this curriculum isn't only CS)
    ConceptDefinition('Project Management', ['project management']),
    ConceptDefinition('Business Analysis', ['business analysis', 'business analyst']),
    ConceptDefinition('Marketing', ['marketing']),
    ConceptDefinition('Accounting', ['accounting']),
    ConceptDefinition('Finance', ['finance', 'financial']),
    ConceptDefinition('Economics', ['economics', 'economic']),
    ConceptDefinition('Communication Skills', ['communication skill']),
    ConceptDefinition('Leadership', ['leadership']),
    ConceptDefinition('Japanese Language', ['japanese language', 'jlpt']),
    ConceptDefinition('English Language', ['english language', 'ielts', 'toeic']),
  ];

  /// Finds every [ConceptDefinition] mentioned in [subject]'s `description`
  /// or any of its `learningOutcomes`, in dictionary order, each paired
  /// with the source(s) it was found in.
  static List<ConceptMatch> extract(SubjectRecord subject) {
    final sources = <String, String>{
      if (subject.description.isNotEmpty) 'Mô tả': subject.description,
      for (final lo in subject.learningOutcomes)
        if (lo.detail.isNotEmpty) lo.code: lo.detail,
    };

    final matches = <ConceptMatch>[];
    for (final def in _dictionary) {
      final foundIn = <String>[
        for (final entry in sources.entries)
          if (_mentions(entry.value, def.keywords)) entry.key,
      ];
      if (foundIn.isNotEmpty) {
        matches.add(ConceptMatch(label: def.label, sources: foundIn));
      }
    }
    return matches;
  }

  static bool _mentions(String haystack, List<String> keywords) {
    for (final keyword in keywords) {
      final trimmed = keyword.trim();
      if (trimmed.isEmpty) continue;
      final startsWithWordChar = RegExp(r'^\w').hasMatch(trimmed);
      final endsWithWordChar = RegExp(r'\w$').hasMatch(trimmed);
      final pattern =
          '${startsWithWordChar ? r'\b' : ''}${RegExp.escape(trimmed)}${endsWithWordChar ? r'\b' : ''}';
      if (RegExp(pattern, caseSensitive: false).hasMatch(haystack)) return true;
    }
    return false;
  }

  /// A URL/id-safe slug for a concept label, used to build a stable graph
  /// node id (`"<subjectCode>::concept:<slug>"`).
  static String slug(String label) {
    final lower = label.toLowerCase().trim();
    final slugged = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return slugged.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

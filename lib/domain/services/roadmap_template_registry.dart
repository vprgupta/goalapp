import 'resource_registry.dart';

/// Domain-Specific Roadmap Prompt Templates.
/// Ensures the LLM generates curriculum with the right phase names,
/// correct topic counts, and mandatory concepts per domain.
class RoadmapTemplateRegistry {
  /// Returns a domain-specific system constraint to inject into the LLM prompt.
  static String getConstraint({
    required String goalName,
    required String level,
  }) {
    final domain = ResourceRegistry.detectDomain(goalName, goalName);
    final template = _getTemplate(domain, level);
    if (template == null) return _genericConstraint(level);
    return template;
  }

  static String? _getTemplate(String domain, String level) {
    switch (domain) {
      case 'python':
        return '''
DOMAIN CONSTRAINT: Python Programming
Generate EXACTLY 6 phases in this order:
1. "Python Foundations" — Variables, Data Types, Strings, Lists, Tuples, Dicts, Sets, Control Flow, Functions (8-10 topics)
2. "Intermediate Python" — OOP, Classes, Inheritance, Decorators, Generators, File I/O, Exception Handling (7-9 topics)
3. "Standard Library & Tools" — itertools, collections, pathlib, datetime, json, virtual environments, pip (6-8 topics)
4. "Async & Advanced Patterns" — asyncio, threading, multiprocessing, context managers, metaclasses (6-7 topics)
5. "Testing & Quality" — unittest, pytest, mocking, code coverage, type hints, mypy (5-6 topics)
6. "Real-World Project" — Project design, API integration, packaging, deployment, documentation (5-7 topics)

MANDATORY TOPICS (must appear): list comprehension, lambda, map/filter, *args/**kwargs, __dunder__ methods
FORBIDDEN: Do not skip OOP before file I/O. Do not put decorators before closures.
''';

      case 'javascript':
        return '''
DOMAIN CONSTRAINT: JavaScript / Web Development
Generate EXACTLY 6 phases in this order:
1. "JS Foundations" — Variables (let/const/var), Data Types, Functions, Scope, Closures, Arrays, Objects (8-10 topics)
2. "DOM & Browser APIs" — DOM manipulation, Events, Fetch API, LocalStorage, Web APIs, Forms (6-8 topics)
3. "Async JavaScript" — Callbacks, Promises, async/await, Error handling, Event Loop, Microtasks (7-8 topics)
4. "Modern JS (ES6+)" — Arrow Functions, Destructuring, Spread/Rest, Modules, Template Literals, Classes (6-8 topics)
5. "Node.js & Tooling" — Node.js, npm/yarn, CommonJS/ESM, Webpack/Vite, Linting, Testing with Jest (6-7 topics)
6. "Project Architecture" — Design Patterns, Code Organization, Performance, Security, Deployment (5-7 topics)

MANDATORY TOPICS (must appear): hoisting, prototype chain, event delegation, Promise.all, this keyword
FORBIDDEN: async/await must come AFTER Promises. Classes must come AFTER functions.
''';

      case 'flutter':
        return '''
DOMAIN CONSTRAINT: Flutter & Dart Development
Generate EXACTLY 6 phases in this order:
1. "Dart Fundamentals" — Variables, Types, Functions, Classes, Null Safety, Collections, async/await (8-10 topics)
2. "Flutter Core Widgets" — MaterialApp, Scaffold, Column/Row, Container, Text, Image, ListView, Stack (8-10 topics)
3. "State Management" — setState, Provider, Riverpod, StatefulWidget lifecycle, ValueNotifier (6-8 topics)
4. "Navigation & Routing" — Navigator 2.0, GoRouter, Deep Links, Named Routes, Back Stack (5-7 topics)
5. "Data & Networking" — HTTP, REST APIs, JSON parsing, Hive, SQLite, Shared Preferences, Streams (7-8 topics)
6. "Production & Deployment" — Testing (unit/widget/integration), CI/CD, App Signing, Play Store, Performance (6-8 topics)

MANDATORY TOPICS (must appear): StatelessWidget vs StatefulWidget, BuildContext, Widget tree, hot reload
FORBIDDEN: State management must come AFTER core widgets. Navigation must come AFTER state basics.
''';

      case 'java':
        return '''
DOMAIN CONSTRAINT: Java Programming
Generate EXACTLY 6 phases in this order:
1. "Java Basics" — Syntax, Variables, Primitive Types, Operators, Control Flow, Arrays, Strings (8-10 topics)
2. "Object-Oriented Java" — Classes, Objects, Constructors, Encapsulation, Inheritance, Polymorphism, Interfaces (8-10 topics)
3. "Core Java APIs" — Collections (List/Set/Map), Generics, Iterators, Comparable, String APIs, Date/Time (7-9 topics)
4. "Advanced Java" — Lambdas, Stream API, Optional, Functional Interfaces, Exception Handling (6-8 topics)
5. "Concurrency & I/O" — Threads, ExecutorService, Synchronization, File I/O, NIO, Serialization (6-7 topics)
6. "Java Ecosystem" — Maven/Gradle, JUnit, Spring basics, JDBC, Design Patterns, JVM tuning (6-8 topics)

MANDATORY TOPICS (must appear): SOLID principles, static vs instance, abstract class vs interface, autoboxing
FORBIDDEN: Generics must come AFTER basic OOP. Stream API must come AFTER Lambdas.
''';

      case 'dsa':
        return '''
DOMAIN CONSTRAINT: Data Structures & Algorithms
Generate EXACTLY 6 phases in this order:
1. "Foundations & Complexity" — Big-O notation, Space complexity, Arrays, Strings, Two Pointers, Sliding Window (7-9 topics)
2. "Linear Data Structures" — Linked Lists, Stacks, Queues, Deques, Monotonic Stack, implementation (7-8 topics)
3. "Trees & Recursion" — Recursion, Binary Trees, BST, DFS, BFS, Tree traversals, Recursion patterns (8-10 topics)
4. "Heaps, Hashing & Advanced DS" — Heaps/Priority Queue, Hash Maps, Tries, Union Find, Segment Tree (6-8 topics)
5. "Graph Algorithms" — Graph representation, DFS/BFS on graphs, Topological Sort, Shortest Path, MST (7-9 topics)
6. "Dynamic Programming" — Memoization, Tabulation, 1D DP, 2D DP, Knapsack, LCS, LIS patterns (8-10 topics)

MANDATORY TOPICS (must appear): time complexity analysis, recursion base case, in-order traversal, Dijkstra's algorithm
FORBIDDEN: Trees must come AFTER linear data structures. DP must come AFTER recursion and graphs.
''';

      case 'ml':
        return '''
DOMAIN CONSTRAINT: Machine Learning & Data Science
Generate EXACTLY 6 phases in this order:
1. "Math & Python Foundations" — Linear Algebra, Statistics, Probability, NumPy, Pandas, Matplotlib (7-9 topics)
2. "Classical ML" — Linear Regression, Logistic Regression, Decision Trees, SVM, KNN, Cross-validation (8-10 topics)
3. "Feature Engineering & Model Selection" — Data preprocessing, Feature scaling, Encoding, Hyperparameter tuning, Pipelines (6-8 topics)
4. "Ensemble Methods & Advanced ML" — Random Forest, Gradient Boosting, XGBoost, Bagging, Stacking (6-7 topics)
5. "Deep Learning" — Neural Networks, Backpropagation, CNNs, RNNs, Transformers, PyTorch/TensorFlow (8-10 topics)
6. "MLOps & Real-World" — Model deployment, REST APIs for ML, Docker, MLflow, monitoring, data drift (6-8 topics)

MANDATORY TOPICS (must appear): bias-variance tradeoff, gradient descent, confusion matrix, regularization (L1/L2)
FORBIDDEN: Deep learning must come AFTER classical ML. Ensemble methods must come AFTER single models.
''';

      case 'devops':
        return '''
DOMAIN CONSTRAINT: DevOps & Cloud Engineering
Generate EXACTLY 6 phases in this order:
1. "Linux & Shell" — Linux commands, Bash scripting, File permissions, Process management, SSH, Cron (7-9 topics)
2. "Version Control & CI/CD" — Git advanced, GitHub Actions, GitLab CI, Jenkins, Pipeline concepts (6-8 topics)
3. "Containerization" — Docker basics, Dockerfile, docker-compose, Container networking, Image optimization (7-8 topics)
4. "Orchestration" — Kubernetes architecture, Pods, Deployments, Services, Ingress, Helm, kubectl (8-10 topics)
5. "Cloud Platforms" — AWS/GCP/Azure core services, IAM, VPC, S3/GCS, Lambda, Terraform, IaC (7-9 topics)
6. "Monitoring & Security" — Prometheus, Grafana, ELK Stack, Security scanning, Secret management, SRE practices (6-8 topics)

MANDATORY TOPICS (must appear): CI/CD pipeline, Infrastructure as Code, container vs VM, blue-green deployment
FORBIDDEN: Kubernetes must come AFTER Docker. Cloud must come AFTER containerization.
''';

      default:
        return null;
    }
  }

  static String _genericConstraint(String level) {
    final topicCount = level.contains('beg') ? '6-8' : level.contains('adv') ? '10-14' : '8-10';
    return '''
Generate EXACTLY 6 phases that progress logically from foundational to advanced.
Each phase should have $topicCount topics.
Ensure prerequisites always come BEFORE the concepts that depend on them.
Each topic should be a single, atomic, learnable concept (not a broad category).
''';
  }
}

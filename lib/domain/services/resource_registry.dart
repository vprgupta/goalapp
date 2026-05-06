/// Domain-Aware Resource Registry
///
/// Detects the tech domain from the goal/pillar name and maps each topic
/// to the BEST real resource URLs for that domain — no API keys, no searches,
/// no hallucinations. Direct links to the world's best learning platforms.
class ResourceRegistry {
  // ── Domain Detection ────────────────────────────────────────────────────────

  static String detectDomain(String goalName, String pillarName) {
    final text = '${goalName.toLowerCase()} ${pillarName.toLowerCase()}';

    if (_matches(text, ['python', 'django', 'flask', 'fastapi', 'pandas', 'numpy', 'matplotlib', 'pytorch', 'tensorflow', 'scikit'])) return 'python';
    if (_matches(text, ['javascript', 'js', 'node', 'nodejs', 'express', 'deno', 'bun'])) return 'javascript';
    if (_matches(text, ['typescript', 'ts'])) return 'typescript';
    if (_matches(text, ['react', 'next.js', 'nextjs', 'remix', 'gatsby'])) return 'react';
    if (_matches(text, ['vue', 'nuxt'])) return 'vue';
    if (_matches(text, ['angular'])) return 'angular';
    if (_matches(text, ['flutter', 'dart'])) return 'flutter';
    if (_matches(text, ['java', 'spring', 'maven', 'gradle', 'hibernate', 'jvm'])) return 'java';
    if (_matches(text, ['kotlin', 'android'])) return 'kotlin';
    if (_matches(text, ['swift', 'ios', 'xcode', 'swiftui', 'uikit'])) return 'swift';
    if (_matches(text, ['c++', 'cpp', 'c plus'])) return 'cpp';
    if (_matches(text, ['c#', 'csharp', '.net', 'asp.net', 'dotnet', 'blazor'])) return 'csharp';
    if (_matches(text, ['go', 'golang'])) return 'go';
    if (_matches(text, ['rust'])) return 'rust';
    if (_matches(text, ['sql', 'mysql', 'postgresql', 'postgres', 'sqlite', 'database', 'mongodb', 'nosql', 'redis'])) return 'database';
    if (_matches(text, ['machine learning', 'deep learning', 'neural', 'ml', 'ai', 'data science'])) return 'ml';
    if (_matches(text, ['docker', 'kubernetes', 'k8s', 'devops', 'ci/cd', 'terraform', 'aws', 'cloud', 'gcp', 'azure', 'linux'])) return 'devops';
    if (_matches(text, ['dsa', 'data structure', 'algorithm', 'leetcode', 'competitive', 'graph', 'tree', 'sorting', 'dynamic programming'])) return 'dsa';
    if (_matches(text, ['html', 'css', 'web design', 'frontend', 'sass', 'tailwind', 'bootstrap'])) return 'webdev';
    if (_matches(text, ['git', 'github', 'version control'])) return 'git';
    if (_matches(text, ['system design', 'distributed', 'microservices', 'architecture'])) return 'systemdesign';
    if (_matches(text, ['cybersecurity', 'security', 'ethical hacking', 'penetration', 'ctf'])) return 'security';
    if (_matches(text, ['blockchain', 'solidity', 'web3', 'ethereum', 'smart contract'])) return 'blockchain';

    return 'general';
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Domain Resource Profiles ─────────────────────────────────────────────

  static _DomainProfile getProfile(String domain) {
    switch (domain) {
      case 'python':
        return _DomainProfile(
          officialDocsBase: 'https://docs.python.org/3/search.html?q=',
          devDocsUrl: 'https://devdocs.io/python~3.12/',
          cheatsheetUrl: 'https://quickref.me/python',
          practiceUrl: 'https://www.hackerrank.com/domains/python',
          communityUrl: 'https://realpython.com/',
          roadmapUrl: 'https://roadmap.sh/python',
          ytChannels: 'Corey Schafer OR ArjanCodes OR mCoding OR Tech With Tim OR Sentdex',
          repoUrl: 'https://github.com/TheAlgorithms/Python',
          docsSite: 'site:docs.python.org OR site:realpython.com',
        );

      case 'javascript':
        return _DomainProfile(
          officialDocsBase: 'https://developer.mozilla.org/en-US/search?q=',
          devDocsUrl: 'https://devdocs.io/javascript/',
          cheatsheetUrl: 'https://devhints.io/es6',
          practiceUrl: 'https://javascript.info/',
          communityUrl: 'https://javascript.info/',
          roadmapUrl: 'https://roadmap.sh/javascript',
          ytChannels: 'Fireship OR Traversy Media OR The Net Ninja OR Kevin Powell OR Wes Bos',
          repoUrl: 'https://github.com/airbnb/javascript',
          docsSite: 'site:developer.mozilla.org OR site:javascript.info',
        );

      case 'typescript':
        return _DomainProfile(
          officialDocsBase: 'https://www.typescriptlang.org/docs/handbook/',
          devDocsUrl: 'https://devdocs.io/typescript/',
          cheatsheetUrl: 'https://www.typescriptlang.org/cheatsheets/',
          practiceUrl: 'https://www.typescriptlang.org/play',
          communityUrl: 'https://www.totaltypescript.com/',
          roadmapUrl: 'https://roadmap.sh/typescript',
          ytChannels: 'Matt Pocock OR Fireship OR Jack Herrington OR Web Dev Simplified',
          repoUrl: 'https://github.com/microsoft/TypeScript',
          docsSite: 'site:typescriptlang.org OR site:totaltypescript.com',
        );

      case 'react':
        return _DomainProfile(
          officialDocsBase: 'https://react.dev/reference/react/',
          devDocsUrl: 'https://devdocs.io/react/',
          cheatsheetUrl: 'https://devhints.io/react',
          practiceUrl: 'https://react.dev/learn',
          communityUrl: 'https://react.dev/blog',
          roadmapUrl: 'https://roadmap.sh/react',
          ytChannels: 'Fireship OR Jack Herrington OR Theo OR Web Dev Simplified OR Codevolution',
          repoUrl: 'https://github.com/enaqx/awesome-react',
          docsSite: 'site:react.dev OR site:nextjs.org',
        );

      case 'flutter':
        return _DomainProfile(
          officialDocsBase: 'https://api.flutter.dev/flutter/',
          devDocsUrl: 'https://docs.flutter.dev/',
          cheatsheetUrl: 'https://docs.flutter.dev/reference/widgets',
          practiceUrl: 'https://dartpad.dev/',
          communityUrl: 'https://flutter.dev/community',
          roadmapUrl: 'https://roadmap.sh/flutter',
          ytChannels: 'Flutter OR Reso Coder OR Robert Brunhage OR Johannes Milke OR Rivaan Ranawat',
          repoUrl: 'https://github.com/flutter/flutter',
          docsSite: 'site:docs.flutter.dev OR site:dart.dev',
        );

      case 'java':
        return _DomainProfile(
          officialDocsBase: 'https://docs.oracle.com/en/java/javase/21/docs/api/',
          devDocsUrl: 'https://devdocs.io/openjdk~21/',
          cheatsheetUrl: 'https://devhints.io/java',
          practiceUrl: 'https://www.hackerrank.com/domains/java',
          communityUrl: 'https://www.baeldung.com/',
          roadmapUrl: 'https://roadmap.sh/java',
          ytChannels: 'Amigoscode OR Tim Buchalka OR Coding with John OR Telusko',
          repoUrl: 'https://github.com/TheAlgorithms/Java',
          docsSite: 'site:docs.oracle.com OR site:baeldung.com',
        );

      case 'kotlin':
        return _DomainProfile(
          officialDocsBase: 'https://kotlinlang.org/docs/',
          devDocsUrl: 'https://devdocs.io/kotlin/',
          cheatsheetUrl: 'https://devhints.io/kotlin',
          practiceUrl: 'https://play.kotlinlang.org/',
          communityUrl: 'https://kotlinlang.org/docs/android-overview.html',
          roadmapUrl: 'https://roadmap.sh/android',
          ytChannels: 'Phillip Lackner OR Amigoscode OR Android Developers',
          repoUrl: 'https://github.com/JetBrains/kotlin',
          docsSite: 'site:kotlinlang.org OR site:developer.android.com',
        );

      case 'swift':
        return _DomainProfile(
          officialDocsBase: 'https://developer.apple.com/documentation/swift/',
          devDocsUrl: 'https://devdocs.io/swift/',
          cheatsheetUrl: 'https://www.hackingwithswift.com/quick-start/swiftui',
          practiceUrl: 'https://www.hackingwithswift.com/100',
          communityUrl: 'https://www.hackingwithswift.com/',
          roadmapUrl: 'https://roadmap.sh/ios',
          ytChannels: 'Sean Allen OR Paul Hudson OR Kilo Loco OR iOS Academy',
          repoUrl: 'https://github.com/apple/swift',
          docsSite: 'site:developer.apple.com OR site:hackingwithswift.com',
        );

      case 'cpp':
        return _DomainProfile(
          officialDocsBase: 'https://en.cppreference.com/w/',
          devDocsUrl: 'https://devdocs.io/cpp/',
          cheatsheetUrl: 'https://hackingcpp.com/cpp/cheat_sheets.html',
          practiceUrl: 'https://www.learncpp.com/',
          communityUrl: 'https://www.learncpp.com/',
          roadmapUrl: 'https://roadmap.sh/cpp',
          ytChannels: 'The Cherno OR CppCon OR Jason Turner OR Mosh Hamedani',
          repoUrl: 'https://github.com/TheAlgorithms/C-Plus-Plus',
          docsSite: 'site:cppreference.com OR site:learncpp.com',
        );

      case 'csharp':
        return _DomainProfile(
          officialDocsBase: 'https://learn.microsoft.com/en-us/dotnet/csharp/',
          devDocsUrl: 'https://devdocs.io/csharp/',
          cheatsheetUrl: 'https://devhints.io/csharp',
          practiceUrl: 'https://dotnetfiddle.net/',
          communityUrl: 'https://learn.microsoft.com/en-us/dotnet/',
          roadmapUrl: 'https://roadmap.sh/aspnet-core',
          ytChannels: 'IAmTimCorey OR Nick Chapsas OR Mosh Hamedani OR Raw Coding',
          repoUrl: 'https://github.com/dotnet/dotnet',
          docsSite: 'site:learn.microsoft.com OR site:dotnet.microsoft.com',
        );

      case 'go':
        return _DomainProfile(
          officialDocsBase: 'https://pkg.go.dev/',
          devDocsUrl: 'https://devdocs.io/go/',
          cheatsheetUrl: 'https://devhints.io/go',
          practiceUrl: 'https://go.dev/tour/',
          communityUrl: 'https://go.dev/blog/',
          roadmapUrl: 'https://roadmap.sh/golang',
          ytChannels: 'TechWorld with Nana OR Anthony GG OR Melkey Dev OR Dreams of Code',
          repoUrl: 'https://github.com/golang/go',
          docsSite: 'site:go.dev OR site:pkg.go.dev',
        );

      case 'rust':
        return _DomainProfile(
          officialDocsBase: 'https://doc.rust-lang.org/book/',
          devDocsUrl: 'https://devdocs.io/rust/',
          cheatsheetUrl: 'https://cheats.rs/',
          practiceUrl: 'https://rustlings.cool/',
          communityUrl: 'https://doc.rust-lang.org/book/',
          roadmapUrl: 'https://roadmap.sh/rust',
          ytChannels: 'Let\'s Get Rusty OR No Boilerplate OR Jon Gjengset',
          repoUrl: 'https://github.com/rust-lang/rustlings',
          docsSite: 'site:doc.rust-lang.org OR site:lib.rs',
        );

      case 'database':
        return _DomainProfile(
          officialDocsBase: 'https://www.postgresql.org/docs/current/',
          devDocsUrl: 'https://devdocs.io/postgresql~16/',
          cheatsheetUrl: 'https://devhints.io/mysql',
          practiceUrl: 'https://sqlzoo.net/',
          communityUrl: 'https://use-the-index-luke.com/',
          roadmapUrl: 'https://roadmap.sh/postgresql-dba',
          ytChannels: 'Hussein Nasser OR CMU Database Group OR Fireship OR Traversy Media',
          repoUrl: 'https://github.com/dbeaver/dbeaver',
          docsSite: 'site:postgresql.org OR site:mysql.com OR site:mongodb.com/docs',
        );

      case 'ml':
        return _DomainProfile(
          officialDocsBase: 'https://scikit-learn.org/stable/user_guide.html',
          devDocsUrl: 'https://devdocs.io/scikit_learn/',
          cheatsheetUrl: 'https://ml-cheatsheet.readthedocs.io/',
          practiceUrl: 'https://www.kaggle.com/learn',
          communityUrl: 'https://distill.pub/',
          roadmapUrl: 'https://roadmap.sh/ai-data-scientist',
          ytChannels: 'StatQuest OR Andrej Karpathy OR 3Blue1Brown OR Sentdex OR sentdex',
          repoUrl: 'https://github.com/ageron/handson-ml3',
          docsSite: 'site:scikit-learn.org OR site:pytorch.org/docs OR site:keras.io',
        );

      case 'devops':
        return _DomainProfile(
          officialDocsBase: 'https://docs.docker.com/',
          devDocsUrl: 'https://devdocs.io/',
          cheatsheetUrl: 'https://dockerlabs.collabnix.com/docker/cheatsheet/',
          practiceUrl: 'https://labs.play-with-docker.com/',
          communityUrl: 'https://www.digitalocean.com/community/tutorials',
          roadmapUrl: 'https://roadmap.sh/devops',
          ytChannels: 'TechWorld with Nana OR NetworkChuck OR DevOps Toolkit OR That DevOps Guy',
          repoUrl: 'https://github.com/bregman-arie/devops-exercises',
          docsSite: 'site:docs.docker.com OR site:kubernetes.io/docs OR site:docs.aws.amazon.com',
        );

      case 'dsa':
        return _DomainProfile(
          officialDocsBase: 'https://leetcode.com/explore/',
          devDocsUrl: 'https://visualgo.net/',
          cheatsheetUrl: 'https://www.bigocheatsheet.com/',
          practiceUrl: 'https://leetcode.com/problemset/',
          communityUrl: 'https://cp-algorithms.com/',
          roadmapUrl: 'https://neetcode.io/roadmap',
          ytChannels: 'NeetCode OR Abdul Bari OR Back To Back SWE OR Tushar Roy',
          repoUrl: 'https://github.com/neetcode-gh/leetcode',
          docsSite: 'site:cp-algorithms.com OR site:geeksforgeeks.org',
        );

      case 'webdev':
        return _DomainProfile(
          officialDocsBase: 'https://developer.mozilla.org/en-US/docs/Web/',
          devDocsUrl: 'https://devdocs.io/html/',
          cheatsheetUrl: 'https://htmlcheatsheet.com/',
          practiceUrl: 'https://www.frontendmentor.io/',
          communityUrl: 'https://web.dev/learn/',
          roadmapUrl: 'https://roadmap.sh/frontend',
          ytChannels: 'Kevin Powell OR Web Dev Simplified OR Traversy Media OR Fireship OR The Net Ninja',
          repoUrl: 'https://github.com/bradtraversy/50projects50days',
          docsSite: 'site:developer.mozilla.org OR site:web.dev',
        );

      case 'git':
        return _DomainProfile(
          officialDocsBase: 'https://git-scm.com/docs/',
          devDocsUrl: 'https://devdocs.io/git/',
          cheatsheetUrl: 'https://education.github.com/git-cheat-sheet-education.pdf',
          practiceUrl: 'https://learngitbranching.js.org/',
          communityUrl: 'https://git-scm.com/book/en/v2',
          roadmapUrl: 'https://roadmap.sh/git-github',
          ytChannels: 'Fireship OR Traversy Media OR The Modern Coder',
          repoUrl: 'https://github.com/git/git',
          docsSite: 'site:git-scm.com OR site:docs.github.com',
        );

      case 'systemdesign':
        return _DomainProfile(
          officialDocsBase: 'https://bytebytego.com/',
          devDocsUrl: 'https://github.com/donnemartin/system-design-primer',
          cheatsheetUrl: 'https://roadmap.sh/system-design',
          practiceUrl: 'https://www.educative.io/courses/grokking-the-system-design-interview',
          communityUrl: 'https://blog.bytebytego.com/',
          roadmapUrl: 'https://roadmap.sh/system-design',
          ytChannels: 'ByteByteGo OR System Design Interview OR Gaurav Sen OR Arpit Bhayani',
          repoUrl: 'https://github.com/donnemartin/system-design-primer',
          docsSite: 'site:bytebytego.com OR site:highscalability.com',
        );

      case 'security':
        return _DomainProfile(
          officialDocsBase: 'https://owasp.org/www-project-top-ten/',
          devDocsUrl: 'https://portswigger.net/web-security',
          cheatsheetUrl: 'https://cheatsheetseries.owasp.org/',
          practiceUrl: 'https://tryhackme.com/',
          communityUrl: 'https://portswigger.net/web-security',
          roadmapUrl: 'https://roadmap.sh/cyber-security',
          ytChannels: 'NetworkChuck OR John Hammond OR LiveOverflow OR The Cyber Mentor',
          repoUrl: 'https://github.com/OWASP/Top10',
          docsSite: 'site:owasp.org OR site:portswigger.net',
        );

      case 'blockchain':
        return _DomainProfile(
          officialDocsBase: 'https://docs.soliditylang.org/',
          devDocsUrl: 'https://ethereum.org/en/developers/docs/',
          cheatsheetUrl: 'https://docs.soliditylang.org/en/latest/cheatsheet.html',
          practiceUrl: 'https://www.cryptozombies.io/',
          communityUrl: 'https://ethereum.org/en/developers/',
          roadmapUrl: 'https://roadmap.sh/blockchain',
          ytChannels: 'Patrick Collins OR Dapp University OR Finematics',
          repoUrl: 'https://github.com/smartcontractkit/full-blockchain-solidity-course',
          docsSite: 'site:docs.soliditylang.org OR site:ethereum.org',
        );

      default: // 'general'
        return _DomainProfile(
          officialDocsBase: 'https://devdocs.io/',
          devDocsUrl: 'https://devdocs.io/',
          cheatsheetUrl: 'https://devhints.io/',
          practiceUrl: 'https://exercism.org/',
          communityUrl: 'https://dev.to/',
          roadmapUrl: 'https://roadmap.sh/',
          ytChannels: 'Fireship OR freeCodeCamp OR Traversy Media OR CS50',
          repoUrl: 'https://github.com/sindresorhus/awesome',
          docsSite: 'site:devdocs.io OR site:developer.mozilla.org',
        );
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns 5 rich, domain-aware resource maps for a topic.
  static List<Map<String, String>> buildResources({
    required String topicConcept,
    required String pillarName,
    required String goalName,
    required String level,
  }) {
    final domain = detectDomain(goalName, pillarName);
    final profile = getProfile(domain);

    final String topicEncoded = Uri.encodeComponent(topicConcept);
    final String levelHint = level.toLowerCase().contains('beg')
        ? 'beginner'
        : level.toLowerCase().contains('adv')
            ? 'advanced'
            : 'intermediate';

    // 1. VIDEO — YouTube search targeting the best channels for this domain
    final ytUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$topicConcept $pillarName $levelHint ${profile.ytChannels.split(' OR ').first}')}';

    // 2. DOCS — Domain-specific official documentation (direct link, not a Google search)
    final docsUrl = profile.officialDocsBase.endsWith('=') || profile.officialDocsBase.endsWith('/')
        ? '${profile.officialDocsBase}$topicEncoded'
        : profile.officialDocsBase;

    // 3. INTERACTIVE — Domain-specific practice platform (hardcoded, not generic)
    final practiceUrl = profile.practiceUrl;

    // 4. VISUAL — Domain-specific cheatsheet/visual reference (direct link)
    final cheatUrl = profile.cheatsheetUrl;

    // 5. DEEP DIVE — DevDocs + community for this domain
    final devDocsUrl = profile.devDocsUrl;

    return [
      {
        'type': 'video',
        'title': '$topicConcept — Video Tutorials',
        'url': ytUrl,
        'description': 'Curated YouTube search for $topicConcept, filtered by top $pillarName educators.',
        'source': 'YouTube',
        'quality_note': '🎬 Best Creators',
        'rank': '1',
        'domain': domain,
      },
      {
        'type': 'article',
        'title': '$topicConcept — Official Docs',
        'url': docsUrl,
        'description': 'Official documentation and authoritative reference for $topicConcept in $pillarName.',
        'source': 'Official Docs',
        'quality_note': '📖 Authoritative',
        'rank': '2',
        'domain': domain,
      },
      {
        'type': 'interactive',
        'title': '$topicConcept — Hands-on Practice',
        'url': practiceUrl,
        'description': 'Practice $topicConcept on the #1 recommended platform for $pillarName learners.',
        'source': _practiceSourceLabel(domain),
        'quality_note': '🛠️ Practice',
        'rank': '3',
        'domain': domain,
      },
      {
        'type': 'visual',
        'title': '$topicConcept — Cheatsheet',
        'url': cheatUrl,
        'description': 'Quick-reference cheatsheet and visual summary for $topicConcept.',
        'source': _cheatSourceLabel(domain),
        'quality_note': '🗺️ Cheatsheet',
        'rank': '4',
        'domain': domain,
      },
      {
        'type': 'article',
        'title': '$topicConcept — DevDocs Reference',
        'url': devDocsUrl,
        'description': 'Offline-capable, unified documentation for $pillarName — fast and searchable.',
        'source': 'DevDocs',
        'quality_note': '⭐ Deep Dive',
        'rank': '5',
        'domain': domain,
      },
    ];
  }

  static String _practiceSourceLabel(String domain) {
    const map = {
      'python': 'HackerRank Python',
      'javascript': 'JavaScript.info',
      'dsa': 'LeetCode',
      'webdev': 'Frontend Mentor',
      'git': 'Learn Git Branching',
      'rust': 'Rustlings',
      'swift': '100 Days of Swift',
      'security': 'TryHackMe',
      'blockchain': 'CryptoZombies',
      'ml': 'Kaggle Learn',
      'java': 'HackerRank Java',
      'kotlin': 'Kotlin Playground',
      'database': 'SQLZoo',
      'devops': 'Play with Docker',
      'go': 'Tour of Go',
      'flutter': 'DartPad',
    };
    return map[domain] ?? 'Exercism';
  }

  static String _cheatSourceLabel(String domain) {
    const map = {
      'python': 'QuickRef.me',
      'typescript': 'TS Cheatsheets',
      'cpp': 'HackingCPP',
      'dsa': 'BigO Cheatsheet',
      'git': 'GitHub Education',
      'rust': 'Cheats.rs',
      'security': 'OWASP Cheatsheets',
      'systemdesign': 'roadmap.sh',
    };
    return map[domain] ?? 'devhints.io';
  }
}

class _DomainProfile {
  final String officialDocsBase;
  final String devDocsUrl;
  final String cheatsheetUrl;
  final String practiceUrl;
  final String communityUrl;
  final String roadmapUrl;
  final String ytChannels;
  final String repoUrl;
  final String docsSite;

  const _DomainProfile({
    required this.officialDocsBase,
    required this.devDocsUrl,
    required this.cheatsheetUrl,
    required this.practiceUrl,
    required this.communityUrl,
    required this.roadmapUrl,
    required this.ytChannels,
    required this.repoUrl,
    required this.docsSite,
  });
}

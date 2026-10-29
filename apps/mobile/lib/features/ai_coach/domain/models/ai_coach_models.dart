import 'package:flutter/foundation.dart';

enum AiProposalStatus {
  pending,
  approved,
  rejected,
  edited,
}

enum AiProposalType {
  workout,
  diet,
  progression,
}

class AiDataCompleteness {
  final int scorePercentage;
  final List<String> missingItems;
  final String summary;

  const AiDataCompleteness({
    required this.scorePercentage,
    required this.missingItems,
    required this.summary,
  });

  factory AiDataCompleteness.fromJson(Map<String, dynamic> json) {
    return AiDataCompleteness(
      scorePercentage: json['scorePercentage'] is int
          ? json['scorePercentage']
          : int.tryParse(json['scorePercentage']?.toString() ?? '0') ?? 0,
      missingItems: (json['missingItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      summary: json['summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'scorePercentage': scorePercentage,
    'missingItems': missingItems,
    'summary': summary,
  };
}

class AiProposal {
  final String id;
  final String? clientId;
  final String? clientName;
  final AiProposalType type;
  String title;
  String summary;
  final String reason;
  AiProposalStatus status;
  final dynamic currentData;
  Map<String, dynamic> payload;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? createdAt;

  AiProposal({
    required this.id,
    this.clientId,
    this.clientName,
    required this.type,
    required this.title,
    required this.summary,
    required this.reason,
    this.status = AiProposalStatus.pending,
    this.currentData,
    required this.payload,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.createdAt,
  });

  bool get isPending => status == AiProposalStatus.pending || status == AiProposalStatus.edited;
  bool get isApproved => status == AiProposalStatus.approved;
  bool get isRejected => status == AiProposalStatus.rejected;

  factory AiProposal.fromJson(Map<String, dynamic> json) {
    AiProposalType type = AiProposalType.workout;
    final tStr = (json['type'] ?? json['proposalType'] ?? '').toString().toUpperCase();
    if (tStr.contains('DIET')) {
      type = AiProposalType.diet;
    } else if (tStr.contains('PROGRESSION')) {
      type = AiProposalType.progression;
    }

    AiProposalStatus status = AiProposalStatus.pending;
    final sStr = (json['status'] ?? '').toString().toUpperCase();
    if (sStr == 'APPROVED') {
      status = AiProposalStatus.approved;
    } else if (sStr == 'REJECTED') {
      status = AiProposalStatus.rejected;
    } else if (sStr == 'EDITED') {
      status = AiProposalStatus.edited;
    }

    final rawPayload = json['payload'] ?? json['proposedData'] ?? {};
    final Map<String, dynamic> payloadMap = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    final cId = json['clientId']?.toString() ?? payloadMap['clientId']?.toString();
    final cName = json['clientName']?.toString() ??
        payloadMap['clientName']?.toString() ??
        payloadMap['workoutPlan']?['clientName']?.toString();

    return AiProposal(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      clientId: cId,
      clientName: cName,
      type: type,
      title: json['title']?.toString() ?? 'AI Prescription',
      summary: json['summary']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: status,
      currentData: json['currentData'],
      payload: payloadMap,
      approvedByName: json['approvedByName']?.toString(),
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'].toString()) : null,
      rejectionReason: json['rejectionReason']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'type': type == AiProposalType.diet ? 'DIET' : (type == AiProposalType.progression ? 'PROGRESSION' : 'WORKOUT'),
    'title': title,
    'summary': summary,
    'reason': reason,
    'status': status == AiProposalStatus.approved ? 'APPROVED' : (status == AiProposalStatus.rejected ? 'REJECTED' : (status == AiProposalStatus.edited ? 'EDITED' : 'PENDING')),
    'currentData': currentData,
    'payload': payload,
    'approvedByName': approvedByName,
    'approvedAt': approvedAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'rejectionReason': rejectionReason,
  };
}

class AiReportCard {
  final String title;
  final int? workoutsCompleted;
  final int? foodLogsRecorded;
  final int? checkInsPending;
  final int? clientsNeedReview;
  final String? clientName;
  final String? clientId;
  final String? workoutAdherence;
  final String? foodTracking;
  final String? checkInStatus;

  const AiReportCard({
    required this.title,
    this.workoutsCompleted,
    this.foodLogsRecorded,
    this.checkInsPending,
    this.clientsNeedReview,
    this.clientName,
    this.clientId,
    this.workoutAdherence,
    this.foodTracking,
    this.checkInStatus,
  });

  factory AiReportCard.fromJson(Map<String, dynamic> json) {
    return AiReportCard(
      title: json['title']?.toString() ?? 'Intelligence Report',
      workoutsCompleted: json['workoutsCompleted'] is int ? json['workoutsCompleted'] : null,
      foodLogsRecorded: json['foodLogsRecorded'] is int ? json['foodLogsRecorded'] : null,
      checkInsPending: json['checkInsPending'] is int ? json['checkInsPending'] : null,
      clientsNeedReview: json['clientsNeedReview'] is int ? json['clientsNeedReview'] : null,
      clientName: json['clientName']?.toString(),
      clientId: json['clientId']?.toString(),
      workoutAdherence: json['workoutAdherence']?.toString(),
      foodTracking: json['foodTracking']?.toString(),
      checkInStatus: json['checkInStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'workoutsCompleted': workoutsCompleted,
    'foodLogsRecorded': foodLogsRecorded,
    'checkInsPending': checkInsPending,
    'clientsNeedReview': clientsNeedReview,
    'clientName': clientName,
    'clientId': clientId,
    'workoutAdherence': workoutAdherence,
    'foodTracking': foodTracking,
    'checkInStatus': checkInStatus,
  };
}

class VerifiedClientInfo {
  final String clientId;
  final String displayName;
  final bool verified;

  const VerifiedClientInfo({
    required this.clientId,
    required this.displayName,
    this.verified = true,
  });

  factory VerifiedClientInfo.fromJson(Map<String, dynamic> json) {
    return VerifiedClientInfo(
      clientId: json['clientId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? '',
      verified: json['verified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'displayName': displayName,
    'verified': verified,
  };
}

class AiChatMessage {
  final String id;
  final String sender; // 'ADMIN' or 'AI'
  final String content;
  final String intent;
  final DateTime timestamp;
  final AiDataCompleteness? completeness;
  final AiProposal? proposal;
  final AiReportCard? reportCard;
  final List<String> suggestedFollowUps;
  final bool isError;
  final String? conversationId;
  final String? promptVersion;
  final bool? knowledgeRetrievalEnabled;
  final int? retrievedKnowledgeCount;
  final List<String>? retrievedKnowledgeIds;
  final VerifiedClientInfo? verifiedClient;

  AiChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.intent = 'GENERAL',
    DateTime? timestamp,
    this.completeness,
    this.proposal,
    this.reportCard,
    this.suggestedFollowUps = const [],
    this.isError = false,
    this.conversationId,
    this.promptVersion,
    this.knowledgeRetrievalEnabled,
    this.retrievedKnowledgeCount,
    this.retrievedKnowledgeIds,
    this.verifiedClient,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isAi => sender == 'AI';
  bool get isAdmin => sender == 'ADMIN';

  AiChatMessage copyWith({
    String? id,
    String? sender,
    String? content,
    String? intent,
    DateTime? timestamp,
    AiDataCompleteness? completeness,
    AiProposal? proposal,
    AiReportCard? reportCard,
    List<String>? suggestedFollowUps,
    bool? isError,
    String? conversationId,
    String? promptVersion,
    bool? knowledgeRetrievalEnabled,
    int? retrievedKnowledgeCount,
    List<String>? retrievedKnowledgeIds,
    VerifiedClientInfo? verifiedClient,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      intent: intent ?? this.intent,
      timestamp: timestamp ?? this.timestamp,
      completeness: completeness ?? this.completeness,
      proposal: proposal ?? this.proposal,
      reportCard: reportCard ?? this.reportCard,
      suggestedFollowUps: suggestedFollowUps ?? this.suggestedFollowUps,
      isError: isError ?? this.isError,
      conversationId: conversationId ?? this.conversationId,
      promptVersion: promptVersion ?? this.promptVersion,
      knowledgeRetrievalEnabled: knowledgeRetrievalEnabled ?? this.knowledgeRetrievalEnabled,
      retrievedKnowledgeCount: retrievedKnowledgeCount ?? this.retrievedKnowledgeCount,
      retrievedKnowledgeIds: retrievedKnowledgeIds ?? this.retrievedKnowledgeIds,
      verifiedClient: verifiedClient ?? this.verifiedClient,
    );
  }

  factory AiChatMessage.fromResponse(Map<String, dynamic> json) {
    AiProposal? proposal;
    if (json['proposal'] != null && json['proposal'] is Map) {
      proposal = AiProposal.fromJson(Map<String, dynamic>.from(json['proposal']));
    }

    AiReportCard? reportCard;
    if (json['reportCard'] != null && json['reportCard'] is Map) {
      reportCard = AiReportCard.fromJson(Map<String, dynamic>.from(json['reportCard']));
    }

    AiDataCompleteness? completeness;
    if (json['dataCompleteness'] != null && json['dataCompleteness'] is Map) {
      completeness = AiDataCompleteness.fromJson(Map<String, dynamic>.from(json['dataCompleteness']));
    }

    VerifiedClientInfo? verifiedClient;
    if (json['verifiedClient'] != null && json['verifiedClient'] is Map) {
      verifiedClient = VerifiedClientInfo.fromJson(Map<String, dynamic>.from(json['verifiedClient']));
    }

    final followUps = (json['suggestedFollowUps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final ragIds = (json['retrievedKnowledgeIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return AiChatMessage(
      id: json['id']?.toString() ?? json['messageId']?.toString() ?? 'msg_ai_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('#', '')}',
      sender: 'AI',
      content: json['replyText']?.toString() ?? json['response']?.toString() ?? '',
      intent: json['intent']?.toString() ?? 'GENERAL',
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) : null,
      completeness: completeness,
      proposal: proposal,
      reportCard: reportCard,
      suggestedFollowUps: followUps,
      conversationId: json['conversationId']?.toString(),
      promptVersion: json['promptVersion']?.toString(),
      knowledgeRetrievalEnabled: json['knowledgeRetrievalEnabled'] == true,
      retrievedKnowledgeCount: json['retrievedKnowledgeCount'] is int ? json['retrievedKnowledgeCount'] : null,
      retrievedKnowledgeIds: ragIds,
      verifiedClient: verifiedClient,
    );
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    AiProposal? proposal;
    if (json['proposal'] != null && json['proposal'] is Map) {
      proposal = AiProposal.fromJson(Map<String, dynamic>.from(json['proposal']));
    }

    AiReportCard? reportCard;
    if (json['reportCard'] != null && json['reportCard'] is Map) {
      reportCard = AiReportCard.fromJson(Map<String, dynamic>.from(json['reportCard']));
    }

    AiDataCompleteness? completeness;
    if (json['completeness'] != null && json['completeness'] is Map) {
      completeness = AiDataCompleteness.fromJson(Map<String, dynamic>.from(json['completeness']));
    }

    VerifiedClientInfo? verifiedClient;
    if (json['verifiedClient'] != null && json['verifiedClient'] is Map) {
      verifiedClient = VerifiedClientInfo.fromJson(Map<String, dynamic>.from(json['verifiedClient']));
    }

    final followUps = (json['suggestedFollowUps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final ragIds = (json['retrievedKnowledgeIds'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      parsedTimestamp = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }

    return AiChatMessage(
      id: json['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: json['sender']?.toString() ?? 'AI',
      content: json['content']?.toString() ?? '',
      intent: json['intent']?.toString() ?? 'GENERAL',
      timestamp: parsedTimestamp,
      completeness: completeness,
      proposal: proposal,
      reportCard: reportCard,
      suggestedFollowUps: followUps,
      isError: json['isError'] == true,
      conversationId: json['conversationId']?.toString(),
      promptVersion: json['promptVersion']?.toString(),
      knowledgeRetrievalEnabled: json['knowledgeRetrievalEnabled'] == true,
      retrievedKnowledgeCount: json['retrievedKnowledgeCount'] is int ? json['retrievedKnowledgeCount'] : null,
      retrievedKnowledgeIds: ragIds,
      verifiedClient: verifiedClient,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'content': content,
    'intent': intent,
    'timestamp': timestamp.toIso8601String(),
    'completeness': completeness?.toJson(),
    'proposal': proposal?.toJson(),
    'reportCard': reportCard?.toJson(),
    'suggestedFollowUps': suggestedFollowUps,
    'isError': isError,
    'conversationId': conversationId,
    'promptVersion': promptVersion,
    'knowledgeRetrievalEnabled': knowledgeRetrievalEnabled,
    'retrievedKnowledgeCount': retrievedKnowledgeCount,
    'retrievedKnowledgeIds': retrievedKnowledgeIds,
    'verifiedClient': verifiedClient?.toJson(),
  };
}

class AiDailySummary {
  final String title;
  final String date;
  final int workoutsCompleted;
  final int foodLogsRecorded;
  final int weeklyCheckInsPending;
  final int clientsNeedReview;
  final int totalActiveClients;

  const AiDailySummary({
    required this.title,
    required this.date,
    required this.workoutsCompleted,
    required this.foodLogsRecorded,
    required this.weeklyCheckInsPending,
    required this.clientsNeedReview,
    required this.totalActiveClients,
  });

  factory AiDailySummary.fromJson(Map<String, dynamic> json) {
    return AiDailySummary(
      title: json['title']?.toString() ?? "Today's AI Summary",
      date: json['date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      workoutsCompleted: json['workoutsCompleted'] is int
          ? json['workoutsCompleted']
          : int.tryParse(json['workoutsCompleted']?.toString() ?? '0') ?? 0,
      foodLogsRecorded: json['foodLogsRecorded'] is int
          ? json['foodLogsRecorded']
          : int.tryParse(json['foodLogsRecorded']?.toString() ?? '0') ?? 0,
      weeklyCheckInsPending: json['weeklyCheckInsPending'] is int
          ? json['weeklyCheckInsPending']
          : int.tryParse(json['weeklyCheckInsPending']?.toString() ?? '0') ?? 0,
      clientsNeedReview: json['clientsNeedReview'] is int
          ? json['clientsNeedReview']
          : int.tryParse(json['clientsNeedReview']?.toString() ?? '0') ?? 0,
      totalActiveClients: json['totalActiveClients'] is int
          ? json['totalActiveClients']
          : int.tryParse(json['totalActiveClients']?.toString() ?? '0') ?? 0,
    );
  }

  factory AiDailySummary.fallback({
    String title = "Today's AI Summary",
    String date = 'Today',
    int workoutsCompleted = 0,
    int foodLogsRecorded = 0,
    int weeklyCheckInsPending = 0,
    int clientsNeedReview = 0,
    int totalActiveClients = 0,
  }) {
    return AiDailySummary(
      title: title,
      date: date,
      workoutsCompleted: workoutsCompleted,
      foodLogsRecorded: foodLogsRecorded,
      weeklyCheckInsPending: weeklyCheckInsPending,
      clientsNeedReview: clientsNeedReview,
      totalActiveClients: totalActiveClients,
    );
  }
}

class AiConversationSession {
  final List<AiChatMessage> messages;
  final String? conversationId;

  const AiConversationSession({
    required this.messages,
    this.conversationId,
  });
}

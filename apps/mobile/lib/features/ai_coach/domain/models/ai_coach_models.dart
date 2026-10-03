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
}

class AiProposal {
  final String id;
  final AiProposalType type;
  final String title;
  final String summary;
  final String reason;
  AiProposalStatus status;
  final dynamic currentData;
  Map<String, dynamic> payload;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;

  AiProposal({
    required this.id,
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
  });

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

    return AiProposal(
      id: json['id']?.toString() ?? UniqueKey().toString(),
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
    );
  }
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
      id: UniqueKey().toString(),
      sender: 'AI',
      content: json['replyText']?.toString() ?? json['response']?.toString() ?? '',
      intent: json['intent']?.toString() ?? 'GENERAL',
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

  factory AiDailySummary.fallback() {
    return const AiDailySummary(
      title: "Today's AI Summary",
      date: 'Today',
      workoutsCompleted: 12,
      foodLogsRecorded: 7,
      weeklyCheckInsPending: 4,
      clientsNeedReview: 3,
      totalActiveClients: 18,
    );
  }
}

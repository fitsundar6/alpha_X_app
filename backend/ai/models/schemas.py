from typing import Optional, List, Dict, Any, Union
from pydantic import BaseModel, Field

class AiCoachChatRequest(BaseModel):
    message: str = Field(..., description="Admin natural language prompt")
    conversationId: Optional[str] = Field(None, description="Existing conversation UUID")
    selectedClientId: Optional[str] = Field(None, description="Selected client context (AXG-XXXX or UUID)")
    dateRangePreset: Optional[str] = Field(None, description="today, this_week, last_week, last_30_days, etc.")
    customStartDate: Optional[str] = Field(None, description="ISO Start Date")
    customEndDate: Optional[str] = Field(None, description="ISO End Date")

class DateRangeResponse(BaseModel):
    label: str
    startDate: str
    endDate: str

class SelectedClientResponse(BaseModel):
    id: str
    clientId: Optional[str] = None
    name: str

class DataCompletenessResponse(BaseModel):
    scorePercentage: int
    missingItems: List[str]
    summary: str

class ProposalPayload(BaseModel):
    id: str
    proposalType: str
    status: str
    title: str
    summary: str
    reason: str
    currentData: Optional[Any] = None
    proposedData: Dict[str, Any]

class ReportCardPayload(BaseModel):
    title: str
    workoutsCompleted: Optional[int] = None
    foodLogsRecorded: Optional[int] = None
    checkInsPending: Optional[int] = None
    clientsNeedReview: Optional[int] = None
    clientName: Optional[str] = None
    clientId: Optional[str] = None
    workoutAdherence: Optional[str] = None
    foodTracking: Optional[str] = None
    checkInStatus: Optional[str] = None

class AiCoachChatResponse(BaseModel):
    conversationId: str
    replyText: str
    intent: str
    selectedClient: Optional[SelectedClientResponse] = None
    dateRange: DateRangeResponse
    dataCompleteness: Optional[DataCompletenessResponse] = None
    proposal: Optional[ProposalPayload] = None
    reportCard: Optional[ReportCardPayload] = None
    suggestedFollowUps: List[str] = Field(default_factory=list)

class DailySummaryResponse(BaseModel):
    title: str
    date: str
    workoutsCompleted: int
    foodLogsRecorded: int
    weeklyCheckInsPending: int
    clientsNeedReview: int
    totalActiveClients: int
    attendancesVerifiedToday: int
    attentionItems: List[Dict[str, Any]]

class ProposalActionRequest(BaseModel):
    reason: Optional[str] = None
    editedPayload: Optional[Dict[str, Any]] = None

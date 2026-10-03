import { ToolDefinition, ToolPermission } from '../tool.types';
import { knowledgeStore, KnowledgeDocument, KnowledgeTopic } from '../../knowledge';

export const getFitnessTopicsTool: ToolDefinition = {
  name: 'get_fitness_topics',
  description: 'Returns the list of verified fitness, biomechanics, programming, and sports nutrition topics supported in the Alpha X Gym knowledge repository.',
  category: 'READ',
  permission: ToolPermission.READ_KNOWLEDGE,
  inputSchema: {
    type: 'object',
    properties: {
      topic: {
        type: 'string',
        description: 'Optional filter topic: TRAINING, NUTRITION, RECOVERY, SUPPLEMENTS, COACHING, or ALL',
        enum: ['TRAINING', 'NUTRITION', 'RECOVERY', 'SUPPLEMENTS', 'COACHING', 'ALL'],
      },
    },
    required: [],
    additionalProperties: false,
  },
  handler: async (args, _context) => {
    const allDocs = knowledgeStore.getAll();
    const filterTopic = args?.topic && args.topic.toUpperCase() !== 'ALL' ? (args.topic.toUpperCase() as KnowledgeTopic) : null;

    const filtered = filterTopic
      ? allDocs.filter((d: KnowledgeDocument) => d.topic === filterTopic)
      : allDocs;

    const topics = filtered.map((d: KnowledgeDocument) => ({
      id: d.id,
      title: d.title,
      topic: d.topic,
      subtopic: d.subtopic,
      evidenceLevel: d.evidenceLevel,
      tags: d.tags,
    }));

    return {
      selectedTopic: args?.topic || 'ALL',
      totalAvailableTopics: topics.length,
      topics,
    };
  },
  enabled: true,
};

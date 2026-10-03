import os
import re
import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from backend.ai.config import settings
from backend.ai.database.connection import get_db_cursor

logger = logging.getLogger("alpha_x_ai.rag")

class KnowledgeChunk:
    def __init__(self, id: str, category: str, topic: str, source: str, title: str, content: str, metadata: Dict[str, Any]):
        self.id = id
        self.category = category
        self.topic = topic
        self.source = source
        self.title = title
        self.content = content
        self.metadata = metadata

class AlphaXRAGRetriever:
    """
    RAG Knowledge layer for Alpha X Gym.
    Indexes curated scientific sports science, biomechanics, and nutrition documents.
    """

    def __init__(self):
        self._in_memory_chunks: List[KnowledgeChunk] = []
        self._is_indexed = False

    def parse_markdown_document(self, file_path: Path) -> List[KnowledgeChunk]:
        """Parses a markdown document with optional YAML frontmatter into distinct chunks."""
        text = file_path.read_text(encoding="utf-8")
        metadata: Dict[str, Any] = {
            "source": "Alpha X Knowledge Base",
            "category": "GENERAL",
            "topic": file_path.stem,
            "version": "1.0",
        }

        # Parse YAML frontmatter
        body = text
        if text.startswith("---"):
            parts = text.split("---", 2)
            if len(parts) >= 3:
                frontmatter_text = parts[1]
                body = parts[2]
                for line in frontmatter_text.splitlines():
                    if ":" in line:
                        k, v = line.split(":", 1)
                        metadata[k.strip().lower()] = v.strip()

        category = str(metadata.get("category", file_path.parent.name)).upper()
        topic = str(metadata.get("topic", file_path.stem))
        source = str(metadata.get("source", "Alpha X Science"))

        chunks: List[KnowledgeChunk] = []
        # Split by ## headers
        sections = re.split(r"\n(?=##\s+)", body)
        for i, sec in enumerate(sections):
            sec_trimmed = sec.strip()
            if not sec_trimmed:
                continue

            title_match = re.search(r"^##?\s+(.+)$", sec_trimmed, re.M)
            title = title_match.group(1).strip() if title_match else f"{topic} (Part {i+1})"

            chunk_id = f"{topic}_{i}"
            chunks.append(
                KnowledgeChunk(
                    id=chunk_id,
                    category=category,
                    topic=topic,
                    source=source,
                    title=title,
                    content=sec_trimmed,
                    metadata=metadata,
                )
            )

        return chunks

    def reindex_all_documents(self) -> int:
        """
        Scans knowledge directory, parses documents, and stores in PostgreSQL & memory.
        """
        knowledge_dir = settings.KNOWLEDGE_DIR
        if not knowledge_dir.exists():
            logger.warning(f"Knowledge directory {knowledge_dir} not found.")
            return 0

        all_chunks: List[KnowledgeChunk] = []
        for doc_file in knowledge_dir.rglob("*.md"):
            try:
                chunks = self.parse_markdown_document(doc_file)
                all_chunks.extend(chunks)
            except Exception as e:
                logger.error(f"Error parsing knowledge file {doc_file}: {e}")

        self._in_memory_chunks = all_chunks
        self._is_indexed = True

        # Sync into PostgreSQL ai_knowledge_chunks table
        try:
            with get_db_cursor() as cur:
                cur.execute("DELETE FROM ai_knowledge_chunks;")
                for c in all_chunks:
                    cur.execute("""
                        INSERT INTO ai_knowledge_chunks (
                            category, topic, source, title, content, "metadataJson"
                        ) VALUES (
                            %(category)s, %(topic)s, %(source)s, %(title)s, %(content)s, %(meta)s
                        );
                    """, {
                        "category": c.category,
                        "topic": c.topic,
                        "source": c.source,
                        "title": c.title,
                        "content": c.content,
                        "meta": json.dumps(c.metadata),
                    })
            logger.info(f"RAG reindex complete. Total chunks indexed: {len(all_chunks)}")
        except Exception as e:
            logger.warning(f"Could not persist chunks to DB (running memory-only): {e}")

        return len(all_chunks)

    def search_knowledge(
        self, query: str, category: Optional[str] = None, top_k: int = 3
    ) -> List[Dict[str, Any]]:
        """
        Performs contextual retrieval scoring against the knowledge base.
        Filters by category if specified and ranks by term density and title matching.
        """
        if not self._is_indexed or not self._in_memory_chunks:
            self.reindex_all_documents()

        query_terms = set(re.findall(r"\w+", query.lower()))
        if not query_terms:
            return []

        scored: List[Tuple[float, KnowledgeChunk]] = []

        for chunk in self._in_memory_chunks:
            if category and category.upper() != "ALL" and chunk.category != category.upper():
                continue

            content_lower = chunk.content.lower()
            title_lower = chunk.title.lower()
            topic_lower = chunk.topic.lower()

            score = 0.0
            for term in query_terms:
                if len(term) < 3:
                    continue
                # Title / topic boost
                if term in title_lower:
                    score += 5.0
                if term in topic_lower:
                    score += 4.0
                # Content frequency
                matches = len(re.findall(r"\b" + re.escape(term) + r"\b", content_lower))
                score += matches * 1.5

            if score > 0.0:
                scored.append((score, chunk))

        scored.sort(key=lambda x: x[0], reverse=True)
        results = []
        for s, c in scored[:top_k]:
            results.append({
                "category": c.category,
                "topic": c.topic,
                "title": c.title,
                "source": c.source,
                "content": c.content,
                "score": round(s, 2),
            })
        return results

rag_retriever = AlphaXRAGRetriever()

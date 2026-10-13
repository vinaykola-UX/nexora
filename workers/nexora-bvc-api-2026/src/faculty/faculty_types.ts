/**
 * ============================================================================
 * Faculty Material Deduplication & Student Flow — Type Definitions
 * ============================================================================
 */

export interface CanonicalDocument {
  id?: number;
  file_sha256: string;
  simhash: string | null;
  title: string;
  subject_code: string;
  subject_name: string;
  unit: number;
  topic: string | null;
  file_type: string;
  file_size_bytes: number;
  r2_storage_key: string | null;
  total_chunks: number;
  version: string;
  is_verified: number;
  created_at?: string;
  updated_at?: string;
}

export interface FacultyMaterialShare {
  id?: number;
  canonical_doc_id: number;
  faculty_uid: string;
  faculty_email: string;
  faculty_name: string;
  department: string;
  academic_year: string;
  sections: string;
  is_primary_author: number;
  created_at?: string;
}

export interface StudentMaterialInteraction {
  id?: number;
  canonical_doc_id: number;
  student_uid: string;
  student_roll: string;
  student_name: string | null;
  branch: string | null;
  section: string | null;
  action_type: 'VIEW' | 'DOWNLOAD' | 'ASK_AI';
  created_at?: string;
}

export interface SubjectConceptInsight {
  id?: number;
  subject_code: string;
  unit: number;
  canonical_doc_id: number | null;
  concept_topic: string;
  query_count: number;
  last_queried_at?: string;
}

export interface DuplicateCheckResult {
  status: 'EXACT_MATCH' | 'NEAR_DUPLICATE' | 'UNIQUE';
  existingDocument?: CanonicalDocument;
  similarity?: number;
  message: string;
}

export interface FacultyMaterialWithDoc extends FacultyMaterialShare {
  document?: CanonicalDocument;
}

export interface StudentFlowRecord {
  student_roll: string;
  student_name: string | null;
  branch: string | null;
  section: string | null;
  total_views: number;
  total_downloads: number;
  total_ai_queries: number;
  first_accessed: string;
  last_accessed: string;
}

export interface SubjectInsightSummary {
  subject_code: string;
  total_materials: number;
  total_student_views: number;
  total_downloads: number;
  total_ai_queries: number;
  concept_hotspots: Array<{ topic: string; query_count: number; unit: number }>;
  student_engagement_rate: number;
}

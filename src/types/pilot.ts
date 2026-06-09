import type { UserRole } from '../contexts/AuthContext';

export type TaskStatus = 'open' | 'in_progress' | 'corrected' | 'verified' | 'rejected';
export type TaskPriority = 'low' | 'medium' | 'high';
export type TaskEventType =
  | 'created'
  | 'status_changed'
  | 'assigned'
  | 'photo_uploaded'
  | 'commented'
  | 'updated';

export interface StoreReference {
  id: string;
  code: string;
  name: string;
  store_format: 'Hyper' | 'Super' | 'Proximite' | 'Express' | 'Autre';
  address: string | null;
  city: string;
  region: string;
  country: string;
  latitude: number | null;
  longitude: number | null;
  timezone: string;
  is_active: boolean;
}

export interface ShelfReference {
  id: string;
  store_id: string;
  code: string;
  name: string;
  category: string;
  planogram_url: string | null;
  display_order: number;
  is_active: boolean;
}

export interface TeamMember {
  userId: string;
  storeId: string;
  role: Extract<UserRole, 'chef' | 'manager'>;
  fullName: string;
  shelfIds: string[];
}

export interface TaskPhoto {
  id: string;
  task_id: string;
  storage_path: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  uploaded_by: string;
  created_at: string;
}

export interface ActionTask {
  id: string;
  analysis_id: string | null;
  store_id: string;
  shelf_id: string;
  title: string;
  description: string | null;
  issue_type: string | null;
  product_sku: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  assigned_to: string | null;
  created_by: string;
  due_at: string | null;
  corrected_at: string | null;
  verified_at: string | null;
  rejected_at: string | null;
  created_at: string;
  updated_at: string;
  metadata: Record<string, unknown>;
  photos: TaskPhoto[];
}

export interface TaskEvent {
  id: number;
  task_id: string;
  actor_id: string | null;
  event_type: TaskEventType;
  from_status: TaskStatus | null;
  to_status: TaskStatus | null;
  from_assigned_to: string | null;
  to_assigned_to: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface TaskDraft {
  analysisId?: string;
  storeId: string;
  shelfId: string;
  title: string;
  description?: string;
  issueType?: string;
  productSku?: string;
  priority: TaskPriority;
  dueAt?: string;
  metadata?: Record<string, unknown>;
}

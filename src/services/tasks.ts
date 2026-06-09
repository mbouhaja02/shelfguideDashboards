import type { SupabaseClient } from '@supabase/supabase-js';
import { supabaseClient } from './supabase';
import type {
  ActionTask,
  StoreReference,
  ShelfReference,
  TaskDraft,
  TaskPhoto,
  TaskPriority,
  TaskStatus,
  TeamMember,
} from '../types/pilot';

const TASK_COLUMNS = `
  id,
  analysis_id,
  store_id,
  shelf_id,
  title,
  description,
  issue_type,
  product_sku,
  status,
  priority,
  assigned_to,
  created_by,
  due_at,
  corrected_at,
  verified_at,
  rejected_at,
  created_at,
  updated_at,
  metadata,
  task_photos (
    id,
    task_id,
    storage_path,
    file_name,
    mime_type,
    size_bytes,
    uploaded_by,
    created_at
  )
`;

type TaskRecord = Omit<ActionTask, 'photos'> & {
  task_photos?: TaskPhoto[] | null;
};

function asError(error: unknown, fallback: string): Error {
  if (error instanceof Error) return error;
  if (
    error
    && typeof error === 'object'
    && 'message' in error
    && typeof error.message === 'string'
  ) {
    return new Error(error.message);
  }
  return new Error(fallback);
}

function client(): SupabaseClient {
  if (!supabaseClient) {
    throw new Error('Configuration Supabase manquante.');
  }
  return supabaseClient;
}

async function currentUserId(): Promise<string> {
  const { data, error } = await client().auth.getUser();
  if (error || !data.user) {
    throw new Error(error?.message ?? 'Session utilisateur introuvable.');
  }
  return data.user.id;
}

function normalizeTask(record: TaskRecord): ActionTask {
  return {
    ...record,
    metadata: record.metadata ?? {},
    photos: record.task_photos ?? [],
  };
}

function asTask(record: unknown): ActionTask {
  return normalizeTask(record as TaskRecord);
}

export function taskPriorityFromLabel(priority: 'Haute' | 'Moyenne' | 'Faible'): TaskPriority {
  if (priority === 'Haute') return 'high';
  if (priority === 'Moyenne') return 'medium';
  return 'low';
}

export function taskStatusLabel(status: TaskStatus): string {
  if (status === 'in_progress') return 'Pris en charge';
  if (status === 'corrected') return 'Corrige';
  if (status === 'verified') return 'Valide';
  if (status === 'rejected') return 'A reprendre';
  return 'A traiter';
}

export async function loadTasks(limit = 500): Promise<ActionTask[]> {
  const { data, error } = await client()
    .from('action_tasks')
    .select(TASK_COLUMNS)
    .order('updated_at', { ascending: false })
    .limit(limit);

  if (error) throw asError(error, 'Chargement des taches impossible.');
  return (data ?? []).map(asTask);
}

export async function loadStoreReferences(): Promise<StoreReference[]> {
  const { data, error } = await client()
    .from('stores')
    .select('id, code, name, store_format, address, city, region, country, latitude, longitude, timezone, is_active')
    .eq('is_active', true)
    .order('name');

  if (error) throw asError(error, 'Chargement des magasins impossible.');
  return (data ?? []) as StoreReference[];
}

export async function loadShelfReferences(): Promise<ShelfReference[]> {
  const { data, error } = await client()
    .from('shelves')
    .select('id, store_id, code, name, category, planogram_url, display_order, is_active')
    .eq('is_active', true)
    .order('display_order');

  if (error) throw asError(error, 'Chargement des rayons impossible.');
  return (data ?? []) as ShelfReference[];
}

export async function loadTeamMembers(storeIds?: string[]): Promise<TeamMember[]> {
  let membershipQuery = client()
    .from('store_members')
    .select('store_id, user_id, member_role')
    .eq('is_active', true);

  if (storeIds && storeIds.length > 0) {
    membershipQuery = membershipQuery.in('store_id', storeIds);
  }

  const { data: memberships, error: membershipError } = await membershipQuery;
  if (membershipError) throw asError(membershipError, 'Chargement des membres impossible.');

  const userIds = Array.from(new Set((memberships ?? []).map((row) => String(row.user_id))));
  if (userIds.length === 0) return [];

  const { data: profiles, error: profileError } = await client()
    .from('profiles')
    .select('id, full_name')
    .in('id', userIds);

  if (profileError) throw asError(profileError, 'Chargement des profils impossible.');

  const { data: shelfMemberships, error: shelfMembershipError } = await client()
    .from('shelf_members')
    .select('user_id, shelf_id')
    .in('user_id', userIds)
    .eq('is_active', true);

  if (shelfMembershipError) throw asError(shelfMembershipError, 'Chargement des autorisations rayon impossible.');

  const names = new Map(
    (profiles ?? []).map((profile) => [
      String(profile.id),
      String(profile.full_name || 'Membre magasin'),
    ]),
  );
  const shelfIdsByUser = new Map<string, string[]>();
  for (const membership of shelfMemberships ?? []) {
    const userId = String(membership.user_id);
    shelfIdsByUser.set(userId, [
      ...(shelfIdsByUser.get(userId) ?? []),
      String(membership.shelf_id),
    ]);
  }

  return (memberships ?? []).map((membership) => ({
    userId: String(membership.user_id),
    storeId: String(membership.store_id),
    role: membership.member_role as TeamMember['role'],
    fullName: names.get(String(membership.user_id)) ?? 'Membre magasin',
    shelfIds: shelfIdsByUser.get(String(membership.user_id)) ?? [],
  }));
}

async function findTaskByAnalysis(analysisId: string): Promise<ActionTask | null> {
  const { data, error } = await client()
    .from('action_tasks')
    .select(TASK_COLUMNS)
    .eq('analysis_id', analysisId)
    .maybeSingle();

  if (error) throw asError(error, 'Recherche de la tache impossible.');
  return data ? asTask(data) : null;
}

export async function ensureTaskForAnalysis(
  draft: TaskDraft,
  assignedTo?: string | null,
): Promise<ActionTask> {
  if (!draft.analysisId) {
    throw new Error('Une analyse est requise pour cette tache.');
  }
  if (!draft.storeId || !draft.shelfId) {
    throw new Error('Cette analyse doit etre rattachee a un magasin et un rayon.');
  }

  const existing = await findTaskByAnalysis(draft.analysisId);
  if (existing) return existing;

  const userId = await currentUserId();
  const { data, error } = await client()
    .from('action_tasks')
    .insert({
      analysis_id: draft.analysisId,
      store_id: draft.storeId,
      shelf_id: draft.shelfId,
      title: draft.title,
      description: draft.description ?? null,
      issue_type: draft.issueType ?? null,
      product_sku: draft.productSku ?? null,
      priority: draft.priority,
      assigned_to: assignedTo ?? null,
      created_by: userId,
      due_at: draft.dueAt ?? null,
      metadata: draft.metadata ?? {},
    })
    .select(TASK_COLUMNS)
    .single();

  if (!error && data) return asTask(data);

  if (error?.code === '23505') {
    const concurrentTask = await findTaskByAnalysis(draft.analysisId);
    if (concurrentTask) return concurrentTask;
  }

  throw asError(error, 'Impossible de creer la tache.');
}

export async function createManualTask(draft: TaskDraft): Promise<ActionTask> {
  if (!draft.storeId || !draft.shelfId) {
    throw new Error('Selectionnez un rayon autorise.');
  }

  const userId = await currentUserId();
  const { data, error } = await client()
    .from('action_tasks')
    .insert({
      analysis_id: null,
      store_id: draft.storeId,
      shelf_id: draft.shelfId,
      title: draft.title,
      description: draft.description ?? null,
      issue_type: draft.issueType ?? null,
      product_sku: draft.productSku ?? null,
      priority: draft.priority,
      assigned_to: userId,
      created_by: userId,
      due_at: draft.dueAt ?? null,
      metadata: { ...draft.metadata, source: 'manual_scanner' },
    })
    .select(TASK_COLUMNS)
    .single();

  if (error) throw asError(error, 'Impossible de creer la tache manuelle.');
  return asTask(data);
}

async function updateTask(
  taskId: string,
  changes: Record<string, unknown>,
): Promise<ActionTask> {
  const { data, error } = await client()
    .from('action_tasks')
    .update(changes)
    .eq('id', taskId)
    .select(TASK_COLUMNS)
    .single();

  if (error) throw asError(error, 'Mise a jour de la tache impossible.');
  return asTask(data);
}

export async function claimTask(draft: TaskDraft): Promise<ActionTask> {
  const userId = await currentUserId();
  const task = await ensureTaskForAnalysis(draft, userId);
  return updateTask(task.id, {
    assigned_to: task.assigned_to ?? userId,
    status: 'in_progress',
  });
}

export async function reopenTask(taskId: string): Promise<ActionTask> {
  return updateTask(taskId, { status: 'in_progress' });
}

function safeExtension(file: File): string {
  const nameExtension = file.name.split('.').pop()?.toLowerCase();
  if (nameExtension && /^[a-z0-9]{2,5}$/.test(nameExtension)) return nameExtension;
  if (file.type === 'image/png') return 'png';
  if (file.type === 'image/webp') return 'webp';
  if (file.type === 'image/heic') return 'heic';
  return 'jpg';
}

export async function uploadTaskProof(task: ActionTask, file: File): Promise<TaskPhoto> {
  if (!file.type.startsWith('image/')) {
    throw new Error('La preuve doit etre une image.');
  }
  if (file.size <= 0 || file.size > 10 * 1024 * 1024) {
    throw new Error('La photo doit peser moins de 10 Mo.');
  }

  const userId = await currentUserId();
  const path = `${task.store_id}/${task.id}/${crypto.randomUUID()}.${safeExtension(file)}`;
  const { error: uploadError } = await client()
    .storage
    .from('task-proofs')
    .upload(path, file, {
      cacheControl: '3600',
      contentType: file.type,
      upsert: false,
    });

  if (uploadError) throw asError(uploadError, 'Upload de la preuve impossible.');

  const { data, error } = await client()
    .from('task_photos')
    .insert({
      task_id: task.id,
      storage_path: path,
      file_name: file.name || 'preuve.jpg',
      mime_type: file.type,
      size_bytes: file.size,
      uploaded_by: userId,
    })
    .select('id, task_id, storage_path, file_name, mime_type, size_bytes, uploaded_by, created_at')
    .single();

  if (error) {
    await client().storage.from('task-proofs').remove([path]);
    throw asError(error, 'Enregistrement de la preuve impossible.');
  }

  return data as TaskPhoto;
}

export async function createTaskPhotoUrl(storagePath: string, expiresIn = 300): Promise<string> {
  const { data, error } = await client()
    .storage
    .from('task-proofs')
    .createSignedUrl(storagePath, expiresIn);

  if (error) throw asError(error, 'Creation de l URL signee impossible.');
  return data.signedUrl;
}

export async function correctTask(task: ActionTask, proof?: File): Promise<ActionTask> {
  if (proof) await uploadTaskProof(task, proof);
  return updateTask(task.id, { status: 'corrected' });
}

export async function assignTaskForAnalysis(
  draft: TaskDraft,
  assignedTo: string | null,
): Promise<ActionTask> {
  const task = await ensureTaskForAnalysis(draft, assignedTo);
  if (task.assigned_to === assignedTo) return task;
  return updateTask(task.id, { assigned_to: assignedTo });
}

export async function assignTask(taskId: string, assignedTo: string | null): Promise<ActionTask> {
  return updateTask(taskId, { assigned_to: assignedTo });
}

export async function verifyTask(taskId: string): Promise<ActionTask> {
  return updateTask(taskId, { status: 'verified' });
}

export async function rejectTask(taskId: string): Promise<ActionTask> {
  return updateTask(taskId, { status: 'rejected' });
}

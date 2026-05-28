use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

pub const TEXT_RESOLVER: &str = "text";
pub const IMAGE_RESOLVER: &str = "image";
pub const CT_GOAL_NODE_RESOLVER: &str = "extensions.crafting_table.goal_node";
pub const CT_WORK_SESSION_RESOLVER: &str = "extensions.crafting_table.work_session";
pub const CT_CAPTURE_RESOLVER: &str = "extensions.crafting_table.capture";
pub const CT_REMOTE_CONTINUITY_RESOLVER: &str = "extensions.crafting_table.remote_continuity";

pub const REL_GOAL_EDGE: &str = "ct:goal_edge";
pub const REL_SESSION_GOAL: &str = "ct:session:goal";
pub const REL_CAPTURE_GOAL: &str = "ct:capture:goal";
pub const REL_CAPTURE_SESSION: &str = "ct:capture:session";
pub const REL_SESSION_REMOTE_CONTINUITY: &str = "ct:session:remote_continuity";

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreBlockModel {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub storage: Option<i64>,
    pub resolver: String,
    pub content: String,
}

impl InKCreBlockModel {
    pub fn inline(resolver: impl Into<String>, content: impl Into<String>) -> Self {
        Self {
            id: None,
            storage: None,
            resolver: resolver.into(),
            content: content.into(),
        }
    }

    pub fn json_content<T: Serialize>(
        resolver: impl Into<String>,
        content: &T,
    ) -> Result<Self, serde_json::Error> {
        Ok(Self::inline(resolver, serde_json::to_string(content)?))
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreRelationModel {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    #[serde(default)]
    pub from_: i64,
    #[serde(default)]
    pub to_: i64,
    pub content: String,
}

impl InKCreRelationModel {
    pub fn pending(content: impl Into<String>) -> Self {
        Self {
            id: None,
            from_: 0,
            to_: 0,
            content: content.into(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreOutArcForm {
    pub relation: InKCreRelationModel,
    pub to_subgraph: InKCreSubGraphForm,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreInArcForm {
    pub relation: InKCreRelationModel,
    pub from_subgraph: InKCreSubGraphForm,
}

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreSubGraphForm {
    pub block: InKCreBlockModel,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub out_arcs: Vec<InKCreOutArcForm>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub in_arcs: Vec<InKCreInArcForm>,
}

impl InKCreSubGraphForm {
    pub fn new(block: InKCreBlockModel) -> Self {
        Self {
            block,
            out_arcs: Vec::new(),
            in_arcs: Vec::new(),
        }
    }

    pub fn with_out_arc(
        mut self,
        relation_content: impl Into<String>,
        to_subgraph: InKCreSubGraphForm,
    ) -> Self {
        self.out_arcs.push(InKCreOutArcForm {
            relation: InKCreRelationModel::pending(relation_content),
            to_subgraph,
        });
        self
    }

    pub fn with_in_arc(
        mut self,
        relation_content: impl Into<String>,
        from_subgraph: InKCreSubGraphForm,
    ) -> Self {
        self.in_arcs.push(InKCreInArcForm {
            relation: InKCreRelationModel::pending(relation_content),
            from_subgraph,
        });
        self
    }
}

impl Default for InKCreBlockModel {
    fn default() -> Self {
        Self::inline(TEXT_RESOLVER, "")
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GoalNodeContent {
    pub ct_id: String,
    pub title: String,
    pub summary: String,
    pub system_image: String,
}

impl GoalNodeContent {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        Ok(InKCreSubGraphForm::new(InKCreBlockModel::json_content(
            CT_GOAL_NODE_RESOLVER,
            self,
        )?))
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkSessionStatus {
    Active,
    Paused,
    Done,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkSessionContent {
    pub ct_id: String,
    pub title: String,
    pub status: WorkSessionStatus,
    pub objective: String,
    pub continuity: String,
    #[serde(default)]
    pub activity: Vec<String>,
}

impl WorkSessionContent {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        Ok(InKCreSubGraphForm::new(InKCreBlockModel::json_content(
            CT_WORK_SESSION_RESOLVER,
            self,
        )?))
    }

    pub fn to_goal_subgraph(
        &self,
        goal: &GoalNodeContent,
    ) -> Result<InKCreSubGraphForm, serde_json::Error> {
        Ok(self
            .to_subgraph()?
            .with_out_arc(REL_SESSION_GOAL, goal.to_subgraph()?))
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CaptureKind {
    Text,
    Raw,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CaptureContent {
    pub ct_id: String,
    pub title: String,
    pub detail: String,
    pub created_at: String,
    pub kind: CaptureKind,
}

impl CaptureContent {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        Ok(InKCreSubGraphForm::new(InKCreBlockModel::json_content(
            CT_CAPTURE_RESOLVER,
            self,
        )?))
    }

    pub fn to_native_text_subgraph(&self) -> InKCreSubGraphForm {
        let text = if self.detail.trim().is_empty() {
            self.title.clone()
        } else {
            self.detail.clone()
        };
        InKCreSubGraphForm::new(InKCreBlockModel::inline(TEXT_RESOLVER, text))
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CaptureStorage {
    CraftingTableBlock,
    NativeText,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CaptureIntake {
    pub capture: CaptureContent,
    pub storage: CaptureStorage,
    pub linked_goal: Option<GoalNodeContent>,
    pub linked_session: Option<WorkSessionContent>,
}

impl CaptureIntake {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        let mut graph = match self.storage {
            CaptureStorage::CraftingTableBlock => self.capture.to_subgraph()?,
            CaptureStorage::NativeText => self.capture.to_native_text_subgraph(),
        };

        if let Some(goal) = &self.linked_goal {
            graph = graph.with_out_arc(REL_CAPTURE_GOAL, goal.to_subgraph()?);
        }

        if let Some(session) = &self.linked_session {
            graph = graph.with_out_arc(REL_CAPTURE_SESSION, session.to_subgraph()?);
        }

        Ok(graph)
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoteContinuityContent {
    pub ct_id: String,
    pub host_profile_id: String,
    pub last_connection_at: String,
    #[serde(default)]
    pub transfer_summaries: Vec<String>,
    pub note: String,
}

impl RemoteContinuityContent {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        Ok(InKCreSubGraphForm::new(InKCreBlockModel::json_content(
            CT_REMOTE_CONTINUITY_RESOLVER,
            self,
        )?))
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionNeighborhood {
    pub session: WorkSessionContent,
    pub goal: Option<GoalNodeContent>,
    pub captures: Vec<CaptureContent>,
    pub remote_continuity: Option<RemoteContinuityContent>,
}

impl SessionNeighborhood {
    pub fn to_subgraph(&self) -> Result<InKCreSubGraphForm, serde_json::Error> {
        let mut graph = self.session.to_subgraph()?;

        if let Some(goal) = &self.goal {
            graph = graph.with_out_arc(REL_SESSION_GOAL, goal.to_subgraph()?);
        }

        for capture in &self.captures {
            graph = graph.with_in_arc(REL_CAPTURE_SESSION, capture.to_subgraph()?);
        }

        if let Some(remote_continuity) = &self.remote_continuity {
            graph = graph.with_out_arc(
                REL_SESSION_REMOTE_CONTINUITY,
                remote_continuity.to_subgraph()?,
            );
        }

        Ok(graph)
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct InKCreInsertGraphResponse {
    pub blocks: Vec<InKCreBlockModel>,
    pub relations: Vec<InKCreRelationModel>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum InKCreGraphError {
    Codec(String),
    MissingBlockId { resolver: String },
    Transport(String),
}

impl From<serde_json::Error> for InKCreGraphError {
    fn from(error: serde_json::Error) -> Self {
        Self::Codec(error.to_string())
    }
}

pub trait InKCreGraphStore {
    fn insert_subgraph(
        &mut self,
        graph: InKCreSubGraphForm,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError>;

    fn recent_blocks(
        &mut self,
        resolver: Option<&str>,
        limit: usize,
    ) -> Result<Vec<InKCreBlockModel>, InKCreGraphError>;

    fn relations_by_block(
        &mut self,
        block_id: i64,
    ) -> Result<Vec<InKCreRelationModel>, InKCreGraphError>;

    fn update_block(
        &mut self,
        block_id: i64,
        block: InKCreBlockModel,
    ) -> Result<InKCreBlockModel, InKCreGraphError>;
}

pub struct CraftingTableInKCreApi<Store> {
    store: Store,
}

impl<Store> CraftingTableInKCreApi<Store>
where
    Store: InKCreGraphStore,
{
    pub fn new(store: Store) -> Self {
        Self { store }
    }

    pub fn store(&self) -> &Store {
        &self.store
    }

    pub fn store_mut(&mut self) -> &mut Store {
        &mut self.store
    }

    pub fn into_store(self) -> Store {
        self.store
    }

    pub fn save_goal_node(
        &mut self,
        goal: &GoalNodeContent,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError> {
        self.store.insert_subgraph(goal.to_subgraph()?)
    }

    pub fn update_goal_node(
        &mut self,
        block_id: i64,
        goal: &GoalNodeContent,
    ) -> Result<StoredGoalNode, InKCreGraphError> {
        let block = self.store.update_block(
            block_id,
            InKCreBlockModel::json_content(CT_GOAL_NODE_RESOLVER, goal)?,
        )?;
        let block_id = required_block_id(&block)?;
        let content = serde_json::from_str(&block.content)?;
        Ok(StoredGoalNode { block_id, content })
    }

    pub fn save_goal_edge(
        &mut self,
        from: &GoalNodeContent,
        to: &GoalNodeContent,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError> {
        let graph = from
            .to_subgraph()?
            .with_out_arc(REL_GOAL_EDGE, to.to_subgraph()?);
        self.store.insert_subgraph(graph)
    }

    pub fn save_work_session(
        &mut self,
        session: &WorkSessionContent,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError> {
        self.store.insert_subgraph(session.to_subgraph()?)
    }

    pub fn update_work_session(
        &mut self,
        block_id: i64,
        session: &WorkSessionContent,
    ) -> Result<StoredWorkSession, InKCreGraphError> {
        let block = self.store.update_block(
            block_id,
            InKCreBlockModel::json_content(CT_WORK_SESSION_RESOLVER, session)?,
        )?;
        let block_id = required_block_id(&block)?;
        let content = serde_json::from_str(&block.content)?;
        Ok(StoredWorkSession { block_id, content })
    }

    pub fn save_capture(
        &mut self,
        intake: &CaptureIntake,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError> {
        self.store.insert_subgraph(intake.to_subgraph()?)
    }

    pub fn update_capture(
        &mut self,
        block_id: i64,
        capture: &CaptureContent,
    ) -> Result<StoredCapture, InKCreGraphError> {
        let block = self.store.update_block(
            block_id,
            InKCreBlockModel::json_content(CT_CAPTURE_RESOLVER, capture)?,
        )?;
        let block_id = required_block_id(&block)?;
        let content = serde_json::from_str(&block.content)?;
        Ok(StoredCapture { block_id, content })
    }

    pub fn load_goal_forest(
        &mut self,
        limit: usize,
    ) -> Result<GoalForestSnapshot, InKCreGraphError> {
        let blocks = self
            .store
            .recent_blocks(Some(CT_GOAL_NODE_RESOLVER), limit)?;
        let mut nodes = Vec::with_capacity(blocks.len());
        let mut block_id_to_ct_id = HashMap::new();

        for block in blocks {
            let block_id = required_block_id(&block)?;
            let content: GoalNodeContent = serde_json::from_str(&block.content)?;
            block_id_to_ct_id.insert(block_id, content.ct_id.clone());
            nodes.push(StoredGoalNode { block_id, content });
        }

        let mut edges = Vec::new();
        let mut edge_keys = HashSet::new();

        for node in &nodes {
            let relations = self.store.relations_by_block(node.block_id)?;
            for relation in relations
                .into_iter()
                .filter(|relation| relation.content == REL_GOAL_EDGE)
            {
                let Some(from_ct_id) = block_id_to_ct_id.get(&relation.from_) else {
                    continue;
                };
                let Some(to_ct_id) = block_id_to_ct_id.get(&relation.to_) else {
                    continue;
                };
                let key = (
                    relation.id,
                    relation.from_,
                    relation.to_,
                    relation.content.clone(),
                );
                if edge_keys.insert(key) {
                    edges.push(StoredGoalEdge {
                        relation_id: relation.id,
                        from_ct_id: from_ct_id.clone(),
                        to_ct_id: to_ct_id.clone(),
                    });
                }
            }
        }

        Ok(GoalForestSnapshot { nodes, edges })
    }

    pub fn list_captures(&mut self, limit: usize) -> Result<Vec<StoredCapture>, InKCreGraphError> {
        let blocks = self.store.recent_blocks(Some(CT_CAPTURE_RESOLVER), limit)?;
        blocks
            .into_iter()
            .map(|block| {
                let block_id = required_block_id(&block)?;
                let content: CaptureContent = serde_json::from_str(&block.content)?;
                Ok(StoredCapture { block_id, content })
            })
            .collect()
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StoredGoalNode {
    pub block_id: i64,
    pub content: GoalNodeContent,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StoredGoalEdge {
    pub relation_id: Option<i64>,
    pub from_ct_id: String,
    pub to_ct_id: String,
}

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GoalForestSnapshot {
    pub nodes: Vec<StoredGoalNode>,
    pub edges: Vec<StoredGoalEdge>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StoredCapture {
    pub block_id: i64,
    pub content: CaptureContent,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StoredWorkSession {
    pub block_id: i64,
    pub content: WorkSessionContent,
}

fn required_block_id(block: &InKCreBlockModel) -> Result<i64, InKCreGraphError> {
    block.id.ok_or_else(|| InKCreGraphError::MissingBlockId {
        resolver: block.resolver.clone(),
    })
}

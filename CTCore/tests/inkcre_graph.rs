#![cfg(feature = "inkcre-graph")]

use std::collections::HashMap;

use ct_core::inkcre_graph::{
    CaptureContent, CaptureIntake, CaptureKind, CaptureStorage, CraftingTableInKCreApi,
    GoalNodeContent, InKCreBlockModel, InKCreGraphError, InKCreGraphStore,
    InKCreInsertGraphResponse, InKCreRelationModel, InKCreSubGraphForm, SessionNeighborhood,
    WorkSessionContent, WorkSessionStatus, CT_CAPTURE_RESOLVER, CT_GOAL_NODE_RESOLVER,
    REL_CAPTURE_SESSION, REL_GOAL_EDGE, REL_SESSION_GOAL,
};

#[test]
fn goal_node_maps_to_inkcre_block_with_json_content() {
    let goal = GoalNodeContent {
        ct_id: "node-focus".to_string(),
        title: "Focus".to_string(),
        summary: "Stabilize current work.".to_string(),
        system_image: "scope".to_string(),
    };

    let graph = goal.to_subgraph().expect("goal node graph");
    let content: serde_json::Value =
        serde_json::from_str(&graph.block.content).expect("block content json");

    assert_eq!(graph.block.resolver, CT_GOAL_NODE_RESOLVER);
    assert_eq!(content["ctId"], "node-focus");
    assert_eq!(content["systemImage"], "scope");
    assert!(graph.out_arcs.is_empty());
    assert!(graph.in_arcs.is_empty());
}

#[test]
fn session_neighborhood_maps_links_to_inkcre_arcs() {
    let graph = SessionNeighborhood {
        session: WorkSessionContent {
            ct_id: "session-a".to_string(),
            title: "Implement mapping".to_string(),
            status: WorkSessionStatus::Active,
            objective: "Move CT graph concepts toward InKCre.".to_string(),
            continuity: "Phase 4".to_string(),
            activity: vec!["Started mapping.".to_string()],
        },
        goal: Some(GoalNodeContent {
            ct_id: "node-a".to_string(),
            title: "Architecture".to_string(),
            summary: "Multi-client foundation.".to_string(),
            system_image: "point.3.connected.trianglepath.dotted".to_string(),
        }),
        captures: vec![CaptureContent {
            ct_id: "capture-a".to_string(),
            title: "Note".to_string(),
            detail: "Use InKCre block/relation graph.".to_string(),
            created_at: "2026-05-28T00:00:00Z".to_string(),
            kind: CaptureKind::Text,
        }],
        remote_continuity: None,
    }
    .to_subgraph()
    .expect("session graph");

    assert_eq!(graph.out_arcs.len(), 1);
    assert_eq!(graph.out_arcs[0].relation.content, REL_SESSION_GOAL);
    assert_eq!(graph.in_arcs.len(), 1);
    assert_eq!(graph.in_arcs[0].relation.content, REL_CAPTURE_SESSION);

    let encoded = serde_json::to_value(&graph).expect("graph encodes");
    assert_eq!(encoded["out_arcs"][0]["relation"]["from_"], 0);
    assert_eq!(encoded["out_arcs"][0]["relation"]["to_"], 0);
    assert_eq!(
        encoded["in_arcs"][0]["from_subgraph"]["block"]["resolver"],
        "extensions.crafting_table.capture"
    );
}

#[test]
fn native_text_capture_uses_inkcre_text_resolver() {
    let capture = CaptureContent {
        ct_id: "capture-text".to_string(),
        title: "Fallback title".to_string(),
        detail: "Plain text note".to_string(),
        created_at: "2026-05-28T00:00:00Z".to_string(),
        kind: CaptureKind::Text,
    };

    let graph: InKCreSubGraphForm = capture.to_native_text_subgraph();

    assert_eq!(graph.block.resolver, "text");
    assert_eq!(graph.block.content, "Plain text note");
}

#[test]
fn client_api_saves_capture_with_linked_goal() {
    let mut api = CraftingTableInKCreApi::new(FakeStore::default());
    let intake = CaptureIntake {
        capture: CaptureContent {
            ct_id: "capture-linked".to_string(),
            title: "Capture".to_string(),
            detail: "Remember this for the goal.".to_string(),
            created_at: "2026-05-28T00:00:00Z".to_string(),
            kind: CaptureKind::Raw,
        },
        storage: CaptureStorage::CraftingTableBlock,
        linked_goal: Some(GoalNodeContent {
            ct_id: "goal-linked".to_string(),
            title: "Goal".to_string(),
            summary: "Linked goal".to_string(),
            system_image: "scope".to_string(),
        }),
        linked_session: None,
    };

    api.save_capture(&intake).expect("capture saved");
    let store = api.into_store();
    let graph = store.inserted_graphs.first().expect("inserted graph");

    assert_eq!(graph.block.resolver, CT_CAPTURE_RESOLVER);
    assert_eq!(graph.out_arcs.len(), 1);
    assert_eq!(graph.out_arcs[0].relation.content, "ct:capture:goal");
    assert_eq!(
        graph.out_arcs[0].to_subgraph.block.resolver,
        CT_GOAL_NODE_RESOLVER
    );
}

#[test]
fn client_api_loads_goal_forest_projection() {
    let goal_a = stored_goal_block(11, "goal-a", "Goal A");
    let goal_b = stored_goal_block(12, "goal-b", "Goal B");
    let mut store = FakeStore::default();
    store.recent_blocks_by_resolver.insert(
        CT_GOAL_NODE_RESOLVER.to_string(),
        vec![goal_a.clone(), goal_b.clone()],
    );
    store.relations_by_block.insert(
        11,
        vec![InKCreRelationModel {
            id: Some(101),
            from_: 11,
            to_: 12,
            content: REL_GOAL_EDGE.to_string(),
        }],
    );
    store.relations_by_block.insert(12, Vec::new());

    let mut api = CraftingTableInKCreApi::new(store);
    let snapshot = api.load_goal_forest(20).expect("goal forest loads");

    assert_eq!(snapshot.nodes.len(), 2);
    assert_eq!(snapshot.nodes[0].content.ct_id, "goal-a");
    assert_eq!(snapshot.edges.len(), 1);
    assert_eq!(snapshot.edges[0].from_ct_id, "goal-a");
    assert_eq!(snapshot.edges[0].to_ct_id, "goal-b");
}

#[test]
fn client_api_lists_ct_capture_blocks() {
    let capture = CaptureContent {
        ct_id: "capture-a".to_string(),
        title: "Capture A".to_string(),
        detail: "Stored as CT capture.".to_string(),
        created_at: "2026-05-28T00:00:00Z".to_string(),
        kind: CaptureKind::Raw,
    };
    let mut store = FakeStore::default();
    store.recent_blocks_by_resolver.insert(
        CT_CAPTURE_RESOLVER.to_string(),
        vec![InKCreBlockModel {
            id: Some(21),
            storage: None,
            resolver: CT_CAPTURE_RESOLVER.to_string(),
            content: serde_json::to_string(&capture).expect("capture json"),
        }],
    );

    let mut api = CraftingTableInKCreApi::new(store);
    let captures = api.list_captures(10).expect("captures load");

    assert_eq!(captures.len(), 1);
    assert_eq!(captures[0].block_id, 21);
    assert_eq!(captures[0].content.ct_id, "capture-a");
}

#[test]
fn client_api_updates_goal_node_by_block_id() {
    let mut api = CraftingTableInKCreApi::new(FakeStore::default());
    let updated = GoalNodeContent {
        ct_id: "goal-a".to_string(),
        title: "Updated Goal".to_string(),
        summary: "Updated summary.".to_string(),
        system_image: "scope".to_string(),
    };

    let stored = api
        .update_goal_node(42, &updated)
        .expect("goal node updates");

    assert_eq!(stored.block_id, 42);
    assert_eq!(stored.content.title, "Updated Goal");

    let store = api.into_store();
    assert_eq!(store.updated_blocks.len(), 1);
    assert_eq!(store.updated_blocks[0].0, 42);
    assert_eq!(store.updated_blocks[0].1.resolver, CT_GOAL_NODE_RESOLVER);
}

#[derive(Default)]
struct FakeStore {
    inserted_graphs: Vec<InKCreSubGraphForm>,
    recent_blocks_by_resolver: HashMap<String, Vec<InKCreBlockModel>>,
    relations_by_block: HashMap<i64, Vec<InKCreRelationModel>>,
    updated_blocks: Vec<(i64, InKCreBlockModel)>,
}

impl InKCreGraphStore for FakeStore {
    fn insert_subgraph(
        &mut self,
        graph: InKCreSubGraphForm,
    ) -> Result<InKCreInsertGraphResponse, InKCreGraphError> {
        self.inserted_graphs.push(graph.clone());
        Ok(InKCreInsertGraphResponse {
            blocks: vec![graph.block],
            relations: graph.out_arcs.into_iter().map(|arc| arc.relation).collect(),
        })
    }

    fn recent_blocks(
        &mut self,
        resolver: Option<&str>,
        _limit: usize,
    ) -> Result<Vec<InKCreBlockModel>, InKCreGraphError> {
        Ok(resolver
            .and_then(|resolver| self.recent_blocks_by_resolver.get(resolver).cloned())
            .unwrap_or_default())
    }

    fn relations_by_block(
        &mut self,
        block_id: i64,
    ) -> Result<Vec<InKCreRelationModel>, InKCreGraphError> {
        Ok(self
            .relations_by_block
            .get(&block_id)
            .cloned()
            .unwrap_or_default())
    }

    fn update_block(
        &mut self,
        block_id: i64,
        mut block: InKCreBlockModel,
    ) -> Result<InKCreBlockModel, InKCreGraphError> {
        block.id = Some(block_id);
        self.updated_blocks.push((block_id, block.clone()));
        Ok(block)
    }
}

fn stored_goal_block(block_id: i64, ct_id: &str, title: &str) -> InKCreBlockModel {
    let goal = GoalNodeContent {
        ct_id: ct_id.to_string(),
        title: title.to_string(),
        summary: String::new(),
        system_image: "scope".to_string(),
    };

    InKCreBlockModel {
        id: Some(block_id),
        storage: None,
        resolver: CT_GOAL_NODE_RESOLVER.to_string(),
        content: serde_json::to_string(&goal).expect("goal json"),
    }
}

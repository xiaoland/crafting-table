use crafting_table_windows_native::host_runtime::{
    self, BindMode, HostRuntimeService, RuntimeEventKind, RuntimeState, RuntimeView,
};
use gpui::prelude::FluentBuilder;
use gpui::{
    div, px, rgb, size, App, AppContext, Application, Bounds, Context, Div, FontWeight,
    InteractiveElement, IntoElement, ParentElement, Render, Rgba, Stateful,
    StatefulInteractiveElement, Styled, Window, WindowBounds, WindowOptions,
};

struct WindowsHostApp {
    service: HostRuntimeService,
    view: RuntimeView,
    last_error: Option<String>,
}

impl WindowsHostApp {
    fn new() -> Self {
        let service = HostRuntimeService::default();
        let view = service.view().unwrap_or_else(|message| {
            fallback_view(
                RuntimeState::Failed,
                format!("Failed to read runtime state: {message}"),
            )
        });

        Self {
            service,
            view,
            last_error: None,
        }
    }

    fn refresh_view(&mut self) {
        match self.service.view() {
            Ok(view) => {
                self.view = view;
                self.last_error = None;
            }
            Err(message) => {
                self.last_error = Some(message);
            }
        }
    }

    fn start_runtime(&mut self) {
        match self.service.start() {
            Ok(view) => {
                self.view = view;
                self.last_error = None;
            }
            Err(message) => {
                self.last_error = Some(message);
                self.refresh_view();
            }
        }
    }

    fn stop_runtime(&mut self) {
        match self.service.stop() {
            Ok(view) => {
                self.view = view;
                self.last_error = None;
            }
            Err(message) => {
                self.last_error = Some(message);
                self.refresh_view();
            }
        }
    }

    fn set_bind_mode(&mut self, mode: BindMode) {
        match self.service.set_bind_mode(mode) {
            Ok(view) => {
                self.view = view;
                self.last_error = None;
            }
            Err(message) => {
                self.last_error = Some(message);
            }
        }
    }

    fn can_change_bind(&self) -> bool {
        matches!(
            self.view.state,
            RuntimeState::Stopped | RuntimeState::Failed
        )
    }

    fn can_start(&self) -> bool {
        matches!(
            self.view.state,
            RuntimeState::Stopped | RuntimeState::Failed
        )
    }

    fn can_stop(&self) -> bool {
        self.view.state == RuntimeState::Running
    }

    fn control_button(
        &self,
        id: &'static str,
        label: &'static str,
        enabled: bool,
        primary: bool,
    ) -> Stateful<Div> {
        let base = div()
            .id(id)
            .px_4()
            .py_2()
            .rounded_md()
            .border_1()
            .text_size(px(13.0))
            .child(label);

        let styled = if primary {
            base.bg(rgb(0x245c50))
                .border_color(rgb(0x245c50))
                .text_color(rgb(0xffffff))
        } else {
            base.bg(rgb(0xffffff))
                .border_color(rgb(0xb8c7c1))
                .text_color(rgb(0x162022))
        };

        if enabled {
            styled.cursor_pointer().hover(|this| this.opacity(0.82))
        } else {
            styled.opacity(0.45)
        }
    }

    fn bind_button(&self, mode: BindMode) -> Stateful<Div> {
        let selected = self.view.bind_mode == mode;
        let enabled = self.can_change_bind();
        let button = div()
            .id(match mode {
                BindMode::LocalOnly => "bind-local-only",
                BindMode::LocalNetwork => "bind-local-network",
            })
            .px_3()
            .py_2()
            .rounded_md()
            .text_size(px(13.0))
            .child(mode.label());

        let button = if selected {
            button.bg(rgb(0xffffff)).text_color(rgb(0x152022))
        } else {
            button.bg(rgb(0xeef2ef)).text_color(rgb(0x3f4b4c))
        };

        if enabled {
            button.cursor_pointer().hover(|this| this.opacity(0.82))
        } else {
            button.opacity(0.45)
        }
    }
}

impl Render for WindowsHostApp {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let state_color = match self.view.state {
            RuntimeState::Running => rgb(0x2d7667),
            RuntimeState::Failed => rgb(0xb43d32),
            RuntimeState::Starting | RuntimeState::Stopping => rgb(0x577382),
            RuntimeState::Stopped => rgb(0x66716f),
        };
        let last_error = self.last_error.clone();

        div()
            .size_full()
            .bg(rgb(0xf4f2ed))
            .text_color(rgb(0x152022))
            .font_family(".SystemUIFont")
            .p_6()
            .child(
                div()
                    .w_full()
                    .max_w(px(1040.0))
                    .mx_auto()
                    .flex()
                    .flex_col()
                    .gap_4()
                    .child(
                        div()
                            .flex()
                            .justify_between()
                            .items_center()
                            .child(
                                div()
                                    .flex()
                                    .flex_col()
                                    .gap_1()
                                    .child(
                                        div()
                                            .text_size(px(20.0))
                                            .font_weight(FontWeight(700.0))
                                            .child("Crafting Table"),
                                    )
                                    .child(
                                        div()
                                            .text_size(px(13.0))
                                            .text_color(rgb(0x5f696b))
                                            .child("Codex Remote Server"),
                                    ),
                            )
                            .child(
                                self.control_button("refresh", "Refresh", true, false)
                                    .on_click(cx.listener(|this, _, _, cx| {
                                        this.refresh_view();
                                        cx.notify();
                                    })),
                            ),
                    )
                    .child(
                        div()
                            .grid()
                            .grid_cols(3)
                            .gap_1()
                            .bg(rgb(0xd7ddd8))
                            .border_1()
                            .border_color(rgb(0xd7ddd8))
                            .rounded_md()
                            .overflow_hidden()
                            .child(status_cell(
                                "Status",
                                self.view.state.label(),
                                Some(state_color),
                            ))
                            .child(status_cell("Bind", &self.view.bind_address, None))
                            .child(status_cell("Endpoint", &self.view.endpoint_hint, None)),
                    )
                    .when_some(last_error, |this, message| {
                        this.child(
                            div()
                                .border_1()
                                .border_color(rgb(0xdca09a))
                                .bg(rgb(0xfae7e5))
                                .rounded_md()
                                .p_3()
                                .text_size(px(13.0))
                                .text_color(rgb(0x7d251e))
                                .child(message),
                        )
                    })
                    .child(
                        div()
                            .flex()
                            .justify_between()
                            .items_center()
                            .gap_3()
                            .border_1()
                            .border_color(rgb(0xd7ddd8))
                            .bg(rgb(0xffffff))
                            .rounded_md()
                            .p_3()
                            .child(
                                div()
                                    .flex()
                                    .gap_2()
                                    .p_1()
                                    .rounded_md()
                                    .border_1()
                                    .border_color(rgb(0xcbd5d1))
                                    .bg(rgb(0xeef2ef))
                                    .child(self.bind_button(BindMode::LocalOnly).on_click(
                                        cx.listener(|this, _, _, cx| {
                                            if this.can_change_bind() {
                                                this.set_bind_mode(BindMode::LocalOnly);
                                                cx.notify();
                                            }
                                        }),
                                    ))
                                    .child(self.bind_button(BindMode::LocalNetwork).on_click(
                                        cx.listener(|this, _, _, cx| {
                                            if this.can_change_bind() {
                                                this.set_bind_mode(BindMode::LocalNetwork);
                                                cx.notify();
                                            }
                                        }),
                                    )),
                            )
                            .child(
                                div()
                                    .flex()
                                    .gap_2()
                                    .child(
                                        self.control_button(
                                            "start",
                                            "Start",
                                            self.can_start(),
                                            true,
                                        )
                                        .on_click(
                                            cx.listener(|this, _, _, cx| {
                                                if this.can_start() {
                                                    this.start_runtime();
                                                    cx.notify();
                                                }
                                            }),
                                        ),
                                    )
                                    .child(
                                        self.control_button("stop", "Stop", self.can_stop(), false)
                                            .on_click(cx.listener(|this, _, _, cx| {
                                                if this.can_stop() {
                                                    this.stop_runtime();
                                                    cx.notify();
                                                }
                                            })),
                                    ),
                            ),
                    )
                    .child(
                        div()
                            .grid()
                            .grid_cols(2)
                            .gap_1()
                            .bg(rgb(0xd7ddd8))
                            .border_1()
                            .border_color(rgb(0xd7ddd8))
                            .rounded_md()
                            .overflow_hidden()
                            .child(status_cell("Mode", self.view.bind_mode.label(), None))
                            .child(status_cell("Codex Home", &self.view.codex_home, None)),
                    )
                    .child(
                        div()
                            .min_h(px(260.0))
                            .border_1()
                            .border_color(rgb(0xd7ddd8))
                            .bg(rgb(0xffffff))
                            .rounded_md()
                            .p_4()
                            .child(
                                div()
                                    .text_size(px(14.0))
                                    .font_weight(FontWeight(700.0))
                                    .child("Events"),
                            )
                            .child(
                                div()
                                    .id("event-list")
                                    .mt_3()
                                    .flex()
                                    .flex_col()
                                    .gap_2()
                                    .overflow_y_scroll()
                                    .max_h(px(340.0))
                                    .children(self.view.events.iter().map(event_row)),
                            ),
                    ),
            )
    }
}

fn status_cell(label: &'static str, value: &str, marker: Option<Rgba>) -> impl IntoElement {
    div()
        .bg(rgb(0xffffff))
        .p_4()
        .child(
            div()
                .text_size(px(11.0))
                .font_weight(FontWeight(700.0))
                .text_color(rgb(0x687372))
                .child(label),
        )
        .child(
            div()
                .mt_1()
                .flex()
                .items_center()
                .gap_2()
                .when_some(marker, |this, color| {
                    this.child(div().size_2().rounded_full().bg(color))
                })
                .child(
                    div()
                        .text_size(px(14.0))
                        .font_weight(FontWeight(700.0))
                        .text_color(rgb(0x152022))
                        .overflow_hidden()
                        .child(value.to_owned()),
                ),
        )
}

fn event_row(event: &host_runtime::RuntimeEvent) -> impl IntoElement {
    let color = match event.kind {
        RuntimeEventKind::Server => rgb(0x2d7667),
        RuntimeEventKind::Error => rgb(0xb43d32),
        RuntimeEventKind::Log => rgb(0x577382),
        RuntimeEventKind::Status => rgb(0xa9b2ae),
    };

    div()
        .id(("event", event.id as usize))
        .flex()
        .flex_row()
        .gap_3()
        .items_center()
        .border_1()
        .border_color(rgb(0xdce2df))
        .rounded_md()
        .overflow_hidden()
        .child(div().w(px(4.0)).h_full().bg(color))
        .child(
            div()
                .w(px(72.0))
                .py_2()
                .text_size(px(12.0))
                .text_color(rgb(0x687372))
                .child(event.timestamp.clone()),
        )
        .child(
            div()
                .w(px(80.0))
                .py_2()
                .text_size(px(12.0))
                .font_weight(FontWeight(700.0))
                .text_color(rgb(0x152022))
                .child(event.kind.label()),
        )
        .child(
            div()
                .py_2()
                .pr_3()
                .text_size(px(12.0))
                .text_color(rgb(0x2f393a))
                .child(event.message.clone()),
        )
}

fn fallback_view(state: RuntimeState, message: String) -> RuntimeView {
    RuntimeView {
        state,
        bind_mode: BindMode::LocalOnly,
        bind_address: BindMode::LocalOnly.bind_address(),
        endpoint_hint: BindMode::LocalOnly.endpoint_hint(),
        codex_home: ".codex".to_string(),
        events: vec![host_runtime::RuntimeEvent {
            id: 1,
            kind: RuntimeEventKind::Error,
            message,
            timestamp: "00:00:00".to_string(),
        }],
    }
}

fn main() {
    Application::new().run(|cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(1040.0), px(720.0)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |_, cx| cx.new(|_| WindowsHostApp::new()),
        )
        .expect("failed to open Crafting Table Windows native window");
        cx.activate(true);
    });
}

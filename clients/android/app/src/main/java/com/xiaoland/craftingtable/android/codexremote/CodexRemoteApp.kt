package com.xiaoland.craftingtable.android.codexremote

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.webkit.WebView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.xiaoland.craftingtable.android.CtCoreBridge

@Composable
fun CodexRemoteApp() {
    CraftingTableTheme {
        val context = LocalContext.current
        val scope = rememberCoroutineScope()
        val controller = remember {
            CodexRemoteController(
                profileStore = HostProfileStore(context.applicationContext),
                client = CtCoreCodexRemoteClient(),
                scope = scope,
            )
        }
        CodexRemoteScreen(controller)
    }
}

@Composable
private fun CodexRemoteScreen(controller: CodexRemoteController) {
    val state = controller.activeState
    val navController = rememberNavController()
    Scaffold { inner ->
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
            color = MaterialTheme.colorScheme.background,
        ) {
            NavHost(
                navController = navController,
                startDestination = CodexRemoteRoute.HostThreads,
            ) {
                composable(CodexRemoteRoute.HostThreads) {
                    HostThreadsPage(
                        controller = controller,
                        onOpenThread = { threadId ->
                            controller.selectThread(threadId)
                            navController.navigate(CodexRemoteRoute.ThreadDetail) {
                                launchSingleTop = true
                            }
                        },
                    )
                }
                composable(CodexRemoteRoute.ThreadDetail) {
                    ThreadDetailPage(
                        controller = controller,
                        state = state,
                        onBack = { navController.popBackStack() },
                    )
                }
            }
        }
    }
}

private object CodexRemoteRoute {
    const val HostThreads = "host_threads"
    const val ThreadDetail = "thread_detail"
}

@Composable
private fun HostThreadsPage(
    controller: CodexRemoteController,
    onOpenThread: (String) -> Unit,
) {
    val profile = controller.activeProfile
    val state = controller.activeState
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Header(state.isLoading)
        }
        item {
            HostControls(controller)
        }
        item {
            HostStatus(controller.activeProfile, state)
        }
        if (state.threadCreateErrorMessage != null) {
            item { MessageBand(state.threadCreateErrorMessage, true) }
        }
        if (state.skippedRecords > 0) {
            item { MessageBand("${state.skippedRecords} skipped records", false) }
        }
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SectionTitle("Threads")
                Spacer(Modifier.weight(1f))
                if (state.threads.isNotEmpty()) {
                    Text("${state.threads.size}", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
                }
            }
        }
        if (state.threads.isEmpty() && state.snapshotLoaded) {
            item { EmptyPanel("No Codex threads") }
        }
        state.threads.groupForDisplay().forEach { group ->
            item(key = "group-${group.projectKey}") {
                ProjectHeader(group, state.isCreatingThread, onCreate = { controller.createThread(group) })
            }
            items(group.threads, key = { it.id }) { thread ->
                ThreadRow(
                    thread = thread,
                    selected = thread.id == state.selectedThreadId,
                    onClick = { onOpenThread(thread.id) },
                )
            }
        }
        if (profile == null) {
            item { EmptyPanel("No host configured") }
        }
    }
}

@Composable
private fun ThreadDetailPage(
    controller: CodexRemoteController,
    state: HostRuntimeState,
    onBack: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back to threads")
            }
            Column(Modifier.weight(1f)) {
                Text(
                    text = state.detail?.thread?.title
                        ?: state.threads.firstOrNull { it.id == state.selectedThreadId }?.displayTitle
                        ?: "Thread Detail",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                val host = controller.activeProfile?.displayLabel ?: "Host"
                Text(host, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
            }
            if (state.selectedThreadId != null) {
                IconButton(onClick = { controller.loadThreadDetail(state.selectedThreadId) }, enabled = !state.isLoadingThread) {
                    Icon(Icons.Filled.Refresh, contentDescription = "Refresh thread")
                }
            }
        }
        Divider(Modifier.fillMaxWidth())
        ThreadPane(controller, state, Modifier.weight(1f).fillMaxWidth())
    }
}

@Composable
private fun Header(isLoading: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
            Text("Crafting Table", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
            Text("Codex Remote", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(CtCoreBridge.wireContractLabel(), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
        }
        if (isLoading) CircularProgressIndicator(Modifier.size(26.dp), strokeWidth = 3.dp)
    }
}

@Composable
private fun HostControls(controller: CodexRemoteController) {
    val profile = controller.activeProfile
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MenuButton(
                label = profile?.displayLabel ?: "Host",
                values = controller.profiles.map { it.id to it.displayLabel },
                onSelect = controller::selectHost,
            )
            Spacer(Modifier.weight(1f))
            IconButton(onClick = controller::addHost) { Icon(Icons.Filled.Add, contentDescription = "Add host") }
            IconButton(onClick = controller::deleteSelectedHost, enabled = controller.profiles.size > 1) {
                Icon(Icons.Filled.Delete, contentDescription = "Delete host")
            }
        }
        OutlinedTextField(
            value = profile?.label.orEmpty(),
            onValueChange = controller::updateHostLabel,
            label = { Text("Host name") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = profile?.endpoint.orEmpty(),
                onValueChange = controller::updateEndpoint,
                label = { Text("Endpoint") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Button(onClick = controller::refresh, enabled = !controller.activeState.isLoading) {
                Icon(Icons.Filled.Refresh, contentDescription = null)
            }
        }
    }
}

@Composable
private fun HostStatus(profile: HostProfile?, state: HostRuntimeState) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionTitle("Host")
        when {
            state.errorMessage != null -> MessageBand(state.errorMessage, true)
            state.health != null -> {
                val health = state.health
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pill(if (health.appServerAvailable) "App server" else "App server down", health.appServerAvailable)
                    Pill("${health.os}/${health.arch}", true)
                }
                Text(health.codexHome, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
            }
            else -> EmptyPanel("Connect a Codex Remote Server")
        }
        profile?.lastHealthStatus?.let {
            Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
        }
    }
}

@Composable
private fun ProjectHeader(group: ProjectThreadGroup, creating: Boolean, onCreate: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(group.projectName, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                group.threadCreationCwd?.let {
                    SelectionContainer {
                        Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline, maxLines = 1, overflow = TextOverflow.MiddleEllipsis)
                    }
                }
            }
            Text("${group.threads.size}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
            IconButton(onClick = onCreate, enabled = !creating && group.threadCreationCwd != null) {
                Icon(Icons.Filled.Add, contentDescription = "Create thread")
            }
        }
    }
}

@Composable
private fun ThreadRow(thread: ThreadSummary, selected: Boolean, onClick: () -> Unit) {
    val container = if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = container),
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(thread.displayTitle, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                thread.activeTurn?.let { Pill(it.status, true) }
            }
            Text(thread.status, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
            Text(thread.updatedAt, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
        }
    }
}

@Composable
private fun ThreadPane(controller: CodexRemoteController, state: HostRuntimeState, modifier: Modifier = Modifier) {
    Column(modifier.background(MaterialTheme.colorScheme.background)) {
        TranscriptPane(state, Modifier.weight(1f).fillMaxWidth())
        Divider()
        Composer(controller, state)
    }
}

@Composable
private fun TranscriptPane(state: HostRuntimeState, modifier: Modifier = Modifier) {
    val detail = state.detail
    val existingIds = detail?.transcriptEntries?.map { it.id }?.toSet().orEmpty()
    val streaming = detail?.let { state.streamingMessages.filterNot { entry -> entry.id in existingIds } }.orEmpty()
    val rows = detail?.let { projectTranscriptRows(it.transcriptEntries + streaming) }.orEmpty()
    val showStreamingRow = detail != null &&
        (state.streamingAssistantText.isNotBlank() || (state.streamingStatus != null && streaming.isEmpty()))
    val visibleItemCount = transcriptVisibleItemCount(
        state = state,
        hasDetail = detail != null,
        rowCount = rows.size,
        showStreamingRow = showStreamingRow,
    )
    val listState = rememberLazyListState()
    val scrollFingerprint = listOf(
        state.selectedThreadId.orEmpty(),
        detail?.thread?.id.orEmpty(),
        rows.size.toString(),
        rows.lastOrNull()?.let(::rowKey).orEmpty(),
        state.streamingAssistantText.length.toString(),
        state.streamingStatus.orEmpty(),
        state.streamErrorMessage.orEmpty(),
    ).joinToString("|")

    LaunchedEffect(scrollFingerprint, visibleItemCount) {
        if (detail != null && visibleItemCount > 0) {
            listState.animateScrollToItem(visibleItemCount - 1)
        }
    }

    LazyColumn(
        modifier = modifier.padding(horizontal = 20.dp, vertical = 14.dp),
        state = listState,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (state.threadErrorMessage != null) {
            item { MessageBand(state.threadErrorMessage, true) }
        }
        if (state.isLoadingThread) {
            item { CircularProgressIndicator(Modifier.size(24.dp)) }
        }
        if (detail == null && state.selectedThreadId == null) {
            item { EmptyPanel("Select a Codex thread") }
        } else if (detail == null && !state.isLoadingThread) {
            item { EmptyPanel("Loading thread") }
        } else if (detail != null) {
            item { ThreadMeta(detail.thread) }
            items(rows, key = { rowKey(it) }) { row ->
                when (row) {
                    is TranscriptRow.Message -> TranscriptEntryRow(row.entry)
                    is TranscriptRow.ToolCallGroup -> ToolCallGroupRow(row.entries)
                }
            }
            if (showStreamingRow) {
                item {
                    StreamingRow(state.streamingAssistantText, state.streamingStatus, state.streamingEventCount)
                }
            }
            state.streamErrorMessage?.let { item { MessageBand(it, true) } }
        }
    }
}

private fun transcriptVisibleItemCount(
    state: HostRuntimeState,
    hasDetail: Boolean,
    rowCount: Int,
    showStreamingRow: Boolean,
): Int {
    var count = 0
    if (state.threadErrorMessage != null) count += 1
    if (state.isLoadingThread) count += 1
    count += when {
        !hasDetail && state.selectedThreadId == null -> 1
        !hasDetail && !state.isLoadingThread -> 1
        hasDetail -> {
            1 + rowCount +
                if (showStreamingRow) 1 else 0 +
                if (state.streamErrorMessage != null) 1 else 0
        }
        else -> 0
    }
    return count
}

private fun rowKey(row: TranscriptRow): String = when (row) {
    is TranscriptRow.Message -> "m-${row.entry.id}"
    is TranscriptRow.ToolCallGroup -> "g-${row.entries.joinToString("-") { it.id }}"
}

@Composable
private fun ThreadMeta(thread: ThreadDetail) {
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(thread.title.ifBlank { thread.id }, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            RowText("Status", thread.status)
            RowText("Turns", thread.turnCount.toString())
            RowText("Updated", thread.updatedAt)
            thread.cwd?.let { RowText("CWD", it) }
        }
    }
}

@Composable
private fun TranscriptEntryRow(entry: TranscriptEntry) {
    when (entry) {
        is TranscriptEntry.TextMessage -> MessageRow(entry.role, entry.text, entry.status)
        is TranscriptEntry.GenericEventMessage -> EventRow(entry.kind, entry.text, entry.status)
        is TranscriptEntry.ToolCallMessage -> ToolCallGroupRow(listOf(entry))
    }
}

@Composable
private fun MessageRow(role: String, text: String, status: String?) {
    val isUser = role == "user"
    val container = if (isUser) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start) {
        Card(
            modifier = Modifier.fillMaxWidth(if (isUser) 0.82f else 0.92f),
            shape = RoundedCornerShape(8.dp),
            colors = CardDefaults.cardColors(containerColor = container),
        ) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row {
                    Text(if (isUser) "You" else "Codex", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    status?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline) }
                }
                RichMessageText(text.ifBlank { "-" })
            }
        }
    }
}

@Composable
private fun EventRow(kind: String, text: String, status: String?) {
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row {
                Text(kind, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                status?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline) }
            }
            SelectionContainer { Text(text.ifBlank { "-" }, style = MaterialTheme.typography.bodyMedium) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ToolCallGroupRow(entries: List<TranscriptEntry.ToolCallMessage>) {
    var detailsOpen by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val title = entries.firstOrNull()?.kind ?: "Tool"
    if (detailsOpen) {
        ToolCallDetailSheet(
            entries = entries,
            sheetState = sheetState,
            onDismiss = { detailsOpen = false },
        )
    }
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { detailsOpen = true },
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(Modifier.padding(horizontal = 10.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    if (entries.size > 1) "$title x${entries.size}" else title,
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text("Details", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
            }
            entries.forEach { entry ->
                Text(
                    entry.payload.summary.ifBlank { entry.kind },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ToolCallDetailSheet(
    entries: List<TranscriptEntry.ToolCallMessage>,
    sheetState: androidx.compose.material3.SheetState,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.82f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Tool details", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            entries.forEachIndexed { index, entry ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        if (entries.size > 1) "${entry.kind} ${index + 1}/${entries.size}" else entry.kind,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    if (entry.payload.summary.isNotBlank()) {
                        SelectionContainer {
                            Text(entry.payload.summary, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                    CodeBlock(entry.payload.detailText, language = "text")
                }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun StreamingRow(text: String, status: String?, eventCount: Int) {
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Codex", fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.width(8.dp))
                status?.let { Pill(it, true) }
                Spacer(Modifier.weight(1f))
                if (eventCount > 0) Text("$eventCount events", style = MaterialTheme.typography.labelSmall)
            }
            if (text.isBlank()) CircularProgressIndicator(Modifier.size(20.dp)) else RichMessageText(text)
        }
    }
}

@Composable
private fun RichMessageText(text: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        parseRichBlocks(text).forEach { block ->
            when (block.kind) {
                RichBlock.Kind.Markdown -> MarkdownText(block.text)
                RichBlock.Kind.Code -> CodeBlock(block.text, block.language ?: "text")
                RichBlock.Kind.Mermaid -> MermaidBlock(block.text)
            }
        }
    }
}

@Composable
private fun MarkdownText(text: String) {
    val linkColor = MaterialTheme.colorScheme.primary
    SelectionContainer {
        Text(
            markdownAnnotatedString(text, linkColor),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

private fun markdownAnnotatedString(text: String, linkColor: Color): AnnotatedString =
    buildAnnotatedString {
        text.lines().forEachIndexed { index, rawLine ->
            val line = rawLine.trimEnd()
            when {
                line.startsWith("### ") -> {
                    withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, fontSize = 17.sp)) {
                        appendInlineMarkdown(line.removePrefix("### "), linkColor)
                    }
                }
                line.startsWith("## ") -> {
                    withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, fontSize = 19.sp)) {
                        appendInlineMarkdown(line.removePrefix("## "), linkColor)
                    }
                }
                line.startsWith("# ") -> {
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold, fontSize = 21.sp)) {
                        appendInlineMarkdown(line.removePrefix("# "), linkColor)
                    }
                }
                line.startsWith("- ") || line.startsWith("* ") -> {
                    append("• ")
                    appendInlineMarkdown(line.drop(2), linkColor)
                }
                Regex("""^\d+\.\s+""").containsMatchIn(line) -> {
                    val match = Regex("""^\d+\.\s+""").find(line)!!
                    append(match.value)
                    appendInlineMarkdown(line.removePrefix(match.value), linkColor)
                }
                line.startsWith("> ") -> {
                    withStyle(SpanStyle(color = Color(0xFF58665F), fontStyle = FontStyle.Italic)) {
                        append("“")
                        appendInlineMarkdown(line.removePrefix("> "), linkColor)
                        append("”")
                    }
                }
                else -> appendInlineMarkdown(line, linkColor)
            }
            if (index != text.lines().lastIndex) append('\n')
        }
    }

private fun AnnotatedString.Builder.appendInlineMarkdown(text: String, linkColor: Color) {
    var index = 0
    while (index < text.length) {
        when {
            text.startsWith("**", index) -> {
                val end = text.indexOf("**", index + 2)
                if (end > index) {
                    withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) {
                        appendInlineMarkdown(text.substring(index + 2, end), linkColor)
                    }
                    index = end + 2
                } else {
                    append(text[index++])
                }
            }
            text[index] == '`' -> {
                val end = text.indexOf('`', index + 1)
                if (end > index) {
                    withStyle(
                        SpanStyle(
                            fontFamily = FontFamily.Monospace,
                            background = Color(0xFFE8EFEA),
                        ),
                    ) {
                        append(text.substring(index + 1, end))
                    }
                    index = end + 1
                } else {
                    append(text[index++])
                }
            }
            text[index] == '*' -> {
                val end = text.indexOf('*', index + 1)
                if (end > index) {
                    withStyle(SpanStyle(fontStyle = FontStyle.Italic)) {
                        appendInlineMarkdown(text.substring(index + 1, end), linkColor)
                    }
                    index = end + 1
                } else {
                    append(text[index++])
                }
            }
            text[index] == '[' -> {
                val closeLabel = text.indexOf(']', index + 1)
                val openUrl = closeLabel.takeIf { it >= 0 }?.let { text.indexOf('(', it + 1) } ?: -1
                val closeUrl = openUrl.takeIf { it == closeLabel + 1 }?.let { text.indexOf(')', it + 1) } ?: -1
                if (closeLabel > index && openUrl == closeLabel + 1 && closeUrl > openUrl) {
                    val label = text.substring(index + 1, closeLabel)
                    val url = text.substring(openUrl + 1, closeUrl)
                    pushStringAnnotation(tag = "URL", annotation = url)
                    withStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)) {
                        append(label)
                    }
                    pop()
                    index = closeUrl + 1
                } else {
                    append(text[index++])
                }
            }
            else -> append(text[index++])
        }
    }
}

@Composable
private fun CodeBlock(code: String, language: String) {
    val clipboard = LocalClipboardManager.current
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFF17201D))) {
        Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(language.ifBlank { "code" }, color = Color(0xFFB6CAC1), style = MaterialTheme.typography.labelSmall)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { clipboard.setText(AnnotatedString(code)) }, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Filled.ContentCopy, contentDescription = "Copy code", tint = Color(0xFFB6CAC1))
                }
            }
            SelectionContainer {
                Text(
                    code.ifBlank { " " },
                    color = Color(0xFFE7F0EC),
                    fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                )
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun MermaidBlock(source: String) {
    var failed by remember(source) { mutableStateOf(false) }
    if (failed) {
        CodeBlock(source, "mermaid")
        return
    }
    Card(shape = RoundedCornerShape(8.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        AndroidView(
            modifier = Modifier.fillMaxWidth().height(320.dp).padding(8.dp),
            factory = { context ->
                WebView(context).apply {
                    settings.javaScriptEnabled = true
                    settings.allowFileAccess = true
                    settings.allowContentAccess = false
                    webViewClient = object : android.webkit.WebViewClient() {
                        override fun onReceivedError(
                            view: WebView?,
                            request: android.webkit.WebResourceRequest?,
                            error: android.webkit.WebResourceError?,
                        ) {
                            failed = true
                        }
                    }
                }
            },
            update = { webView ->
                webView.loadDataWithBaseURL(
                    "file:///android_asset/",
                    mermaidHtml(source),
                    "text/html",
                    "UTF-8",
                    null,
                )
            },
        )
    }
}

private fun mermaidHtml(source: String): String {
    val escaped = source
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="mermaid.min.js"></script>
          <style>body{margin:0;background:#fff;font-family:sans-serif}.mermaid{padding:12px}</style>
        </head>
        <body>
          <pre class="mermaid">$escaped</pre>
          <script>
            mermaid.initialize({ startOnLoad: true, securityLevel: 'strict', theme: 'default' });
          </script>
        </body>
        </html>
    """.trimIndent()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Composer(controller: CodexRemoteController, state: HostRuntimeState) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        OutlinedTextField(
            value = state.input,
            onValueChange = controller::updateInput,
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
            label = { Text("Message Codex") },
            enabled = !state.isSubmitting,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { controller.submitTurn() }),
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ModelControls(controller, state)
            Spacer(Modifier.weight(1f))
            if (state.isSubmitting) CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 3.dp)
            IconButton(onClick = controller::submitTurn, enabled = !state.isSubmitting && state.input.isNotBlank()) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Send")
            }
        }
        state.turnErrorMessage?.let { MessageBand(it, true) }
        state.turnResult?.let {
            Text("Turn ${it.turnId} ${it.status}; ${it.eventCount} events.", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
        }
    }
}

@Composable
private fun ModelControls(controller: CodexRemoteController, state: HostRuntimeState) {
    val selectedModel = state.models.firstOrNull { it.model == state.selectedModel }
    val reasoning = selectedModel?.supportedReasoningEfforts.orEmpty()
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ModelSettingsPicker(controller, state, selectedModel, reasoning)
        MenuButton(
            label = permissionLabel(state.selectedPermissionMode),
            values = listOf("sandbox" to "Sandbox", "auto_review" to "Auto-review", "full_access" to "Full access"),
            onSelect = controller::updatePermission,
        )
    }
}

private enum class ModelPickerPane {
    Main,
    Model,
    Fast,
}

@Composable
private fun ModelSettingsPicker(
    controller: CodexRemoteController,
    state: HostRuntimeState,
    selectedModel: ModelOption?,
    reasoning: List<ReasoningEffortOption>,
) {
    var expanded by remember { mutableStateOf(false) }
    var pane by remember { mutableStateOf(ModelPickerPane.Main) }
    val reasoningLabel = reasoning.firstOrNull { it.reasoningEffort == state.selectedReasoningEffort }?.displayLabel
    val label = listOfNotNull(
        selectedModel?.displayLabel ?: "Models unavailable",
        reasoningLabel,
    ).joinToString(" / ")

    Box {
        OutlinedButton(
            onClick = {
                pane = ModelPickerPane.Main
                expanded = true
            },
            enabled = state.models.isNotEmpty(),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (selectedModel?.supportsFast == true && state.fastServiceTierEnabled) {
                    Icon(
                        Icons.Filled.Bolt,
                        contentDescription = "Fast enabled",
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = {
                expanded = false
                pane = ModelPickerPane.Main
            },
        ) {
            when (pane) {
                ModelPickerPane.Main -> {
                    DropdownMenuItem(
                        text = { Text("Model: ${selectedModel?.displayLabel ?: "Unavailable"}") },
                        onClick = { pane = ModelPickerPane.Model },
                    )
                    if (reasoning.isNotEmpty()) {
                        DropdownSectionLabel("Reasoning")
                        reasoning.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option.displayLabel) },
                                leadingIcon = {
                                    if (option.reasoningEffort == state.selectedReasoningEffort) {
                                        Icon(Icons.Filled.CheckCircle, contentDescription = null)
                                    }
                                },
                                onClick = {
                                    controller.updateSelectedReasoning(option.reasoningEffort)
                                    expanded = false
                                    pane = ModelPickerPane.Main
                                },
                            )
                        }
                    }
                    DropdownMenuItem(
                        text = {
                            Text(
                                if (selectedModel?.supportsFast == true) {
                                    "Fast: ${if (state.fastServiceTierEnabled) "On" else "Off"}"
                                } else {
                                    "Fast: unavailable"
                                },
                            )
                        },
                        enabled = selectedModel?.supportsFast == true,
                        onClick = { pane = ModelPickerPane.Fast },
                    )
                }
                ModelPickerPane.Model -> {
                    DropdownSectionLabel("Model")
                    state.models.forEach { model ->
                        DropdownMenuItem(
                            text = { Text(model.displayLabel) },
                            leadingIcon = {
                                if (model.model == state.selectedModel) {
                                    Icon(Icons.Filled.CheckCircle, contentDescription = null)
                                }
                            },
                            onClick = {
                                controller.updateSelectedModel(model.model)
                                expanded = false
                                pane = ModelPickerPane.Main
                            },
                        )
                    }
                }
                ModelPickerPane.Fast -> {
                    DropdownSectionLabel("Fast")
                    DropdownMenuItem(
                        text = { Text("Off") },
                        leadingIcon = {
                            if (!state.fastServiceTierEnabled) {
                                Icon(Icons.Filled.CheckCircle, contentDescription = null)
                            }
                        },
                        onClick = {
                            controller.updateFast(false)
                            expanded = false
                            pane = ModelPickerPane.Main
                        },
                    )
                    DropdownMenuItem(
                        text = { Text("On") },
                        leadingIcon = {
                            if (state.fastServiceTierEnabled) {
                                Icon(Icons.Filled.CheckCircle, contentDescription = null)
                            }
                        },
                        onClick = {
                            controller.updateFast(true)
                            expanded = false
                            pane = ModelPickerPane.Main
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun DropdownSectionLabel(text: String) {
    Text(
        text,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.outline,
    )
}

@Composable
private fun MenuButton(
    label: String,
    values: List<Pair<String, String>>,
    onSelect: (String) -> Unit,
    enabled: Boolean = true,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, enabled = enabled) {
            Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            values.forEach { (value, text) ->
                DropdownMenuItem(
                    text = { Text(text) },
                    onClick = {
                        expanded = false
                        onSelect(value)
                    },
                )
            }
        }
    }
}

private fun permissionLabel(value: String): String = when (value) {
    "auto_review" -> "Auto-review"
    "full_access" -> "Full access"
    else -> "Sandbox"
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun EmptyPanel(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(8.dp))
            .padding(18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun MessageBand(message: String, error: Boolean) {
    val color = if (error) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.tertiaryContainer
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(color, RoundedCornerShape(8.dp))
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(if (error) Icons.Filled.Error else Icons.Filled.Warning, contentDescription = null)
        Text(message, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun Pill(text: String, good: Boolean) {
    val color = if (good) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.errorContainer
    Row(
        modifier = Modifier.background(color, RoundedCornerShape(999.dp)).padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(if (good) Icons.Filled.CheckCircle else Icons.Filled.Warning, contentDescription = null, modifier = Modifier.size(14.dp))
        Text(text, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun RowText(label: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, color = MaterialTheme.colorScheme.outline, modifier = Modifier.width(76.dp))
        SelectionContainer {
            Text(value, modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun CraftingTableTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Color(0xFF1D5F55),
            onPrimary = Color.White,
            secondary = Color(0xFF665D2D),
            tertiary = Color(0xFF6B4E71),
            background = Color(0xFFF7F8F4),
            surface = Color(0xFFFFFFFF),
            surfaceContainerHigh = Color(0xFFEAF0EC),
            outline = Color(0xFF66736D),
        ),
        content = content,
    )
}

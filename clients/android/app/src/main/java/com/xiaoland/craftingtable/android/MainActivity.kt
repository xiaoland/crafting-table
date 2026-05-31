package com.xiaoland.craftingtable.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            CraftingTableTheme {
                CodexRemoteScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CodexRemoteScreen() {
    val scope = rememberCoroutineScope()
    val wireVersion = remember { CtCoreBridge.wireContractLabel() }

    var hostUrl by rememberSaveable { mutableStateOf("http://127.0.0.1:3765") }
    var health by remember { mutableStateOf<HealthView?>(null) }
    var threads by remember { mutableStateOf<List<ThreadSummaryView>>(emptyList()) }
    var selectedThreadId by remember { mutableStateOf<String?>(null) }
    var detail by remember { mutableStateOf<ThreadDetailView?>(null) }
    var composer by rememberSaveable { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var lastTurn by remember { mutableStateOf<TurnSubmitView?>(null) }

    fun runRequest(block: suspend CodexRemoteApi.() -> Unit) {
        scope.launch {
            busy = true
            error = null
            runCatching {
                CodexRemoteApi(hostUrl).block()
            }.onFailure {
                error = it.message ?: it::class.simpleName ?: "Request failed"
            }
            busy = false
        }
    }

    fun refreshThread(threadId: String) {
        runRequest {
            detail = readThread(threadId)
            selectedThreadId = threadId
        }
    }

    fun submitTurn() {
        val threadId = selectedThreadId ?: return
        val input = composer.trim()
        if (input.isEmpty()) return
        runRequest {
            lastTurn = submitTurn(threadId, input)
            composer = ""
            detail = readThread(threadId)
        }
    }

    Scaffold { innerPadding ->
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            color = MaterialTheme.colorScheme.background,
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Spacer(Modifier.height(18.dp))
                    Header(wireVersion = wireVersion, busy = busy)
                }

                item {
                    OutlinedTextField(
                        value = hostUrl,
                        onValueChange = { hostUrl = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("Host URL") },
                    )
                }

                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = {
                                runRequest {
                                    health = health()
                                }
                            },
                            enabled = !busy,
                        ) {
                            Icon(Icons.Filled.Check, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text("Check")
                        }
                        OutlinedButton(
                            onClick = {
                                runRequest {
                                    health = health()
                                    threads = listThreads()
                                    detail = null
                                    selectedThreadId = null
                                }
                            },
                            enabled = !busy,
                        ) {
                            Icon(Icons.AutoMirrored.Filled.List, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text("Threads")
                        }
                        OutlinedButton(
                            onClick = {
                                selectedThreadId?.let(::refreshThread)
                            },
                            enabled = !busy && selectedThreadId != null,
                        ) {
                            Icon(Icons.Filled.Refresh, contentDescription = null)
                        }
                    }
                }

                error?.let { message ->
                    item {
                        MessageBand(message = message, error = true)
                    }
                }

                health?.let { value ->
                    item {
                        HealthCard(value)
                    }
                }

                lastTurn?.let { value ->
                    item {
                        MessageBand(
                            message = "Turn ${value.turnId} ${value.status}; ${value.eventCount} events.",
                            error = false,
                        )
                    }
                }

                if (threads.isNotEmpty()) {
                    item {
                        SectionTitle("Threads")
                    }
                    items(threads, key = { it.id }) { thread ->
                        ThreadCard(
                            thread = thread,
                            selected = thread.id == selectedThreadId,
                            enabled = !busy,
                            onClick = { refreshThread(thread.id) },
                        )
                    }
                }

                detail?.let { value ->
                    item {
                        SectionTitle(value.title)
                        ThreadMeta(value)
                    }
                    items(value.transcript, key = { it.id + it.role }) { row ->
                        TranscriptCard(row)
                    }
                    item {
                        Composer(
                            value = composer,
                            enabled = !busy,
                            onValueChange = { composer = it },
                            onSubmit = ::submitTurn,
                        )
                    }
                }

                item {
                    Spacer(Modifier.height(20.dp))
                }
            }
        }
    }
}

@Composable
private fun Header(wireVersion: String, busy: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column {
            Text(
                text = "Crafting Table",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Codex Remote",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = wireVersion,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.outline,
            )
        }
        if (busy) {
            CircularProgressIndicator(modifier = Modifier.size(28.dp), strokeWidth = 3.dp)
        }
    }
}

@Composable
private fun HealthCard(value: HealthView) {
    Card(
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            RowLabel("Server", "${value.service} ${value.version}")
            RowLabel("Platform", "${value.os}/${value.arch}")
            RowLabel("Codex", if (value.appServerAvailable) "Available" else value.appServerProbe)
            RowLabel("Home", value.codexHome)
        }
    }
}

@Composable
private fun ThreadCard(
    thread: ThreadSummaryView,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val container = if (selected) {
        MaterialTheme.colorScheme.secondaryContainer
    } else {
        MaterialTheme.colorScheme.surface
    }
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = container),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                text = thread.title,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = thread.projectName.ifBlank { thread.cwd ?: thread.id },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = thread.updatedAt,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.outline,
            )
        }
    }
}

@Composable
private fun ThreadMeta(value: ThreadDetailView) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        RowLabel("Status", value.status)
        RowLabel("Updated", value.updatedAt)
        value.cwd?.let { RowLabel("CWD", it) }
    }
}

@Composable
private fun TranscriptCard(row: TranscriptRowView) {
    Card(
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(row.role, fontWeight = FontWeight.SemiBold)
                row.status?.let {
                    Text(it, color = MaterialTheme.colorScheme.outline)
                }
            }
            Text(
                text = row.text.ifBlank { "-" },
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun Composer(
    value: String,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
            label = { Text("Message") },
            enabled = enabled,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { onSubmit() }),
        )
        Button(
            onClick = onSubmit,
            enabled = enabled && value.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("Send")
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.SemiBold,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
    )
}

@Composable
private fun MessageBand(message: String, error: Boolean) {
    val color = if (error) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.tertiaryContainer
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(color, RoundedCornerShape(8.dp))
            .padding(12.dp),
    ) {
        Text(message, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun RowLabel(label: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = label,
            color = MaterialTheme.colorScheme.outline,
            modifier = Modifier.width(72.dp),
        )
        Text(
            text = value,
            modifier = Modifier.weight(1f),
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )
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

package com.example.ai_watch.tile

import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.ResourceBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import androidx.wear.tiles.TimelineBuilders
import androidx.wear.tiles.LayoutElementBuilders
import androidx.wear.tiles.ModifiersBuilders
import androidx.wear.tiles.ActionBuilders
import androidx.wear.tiles.DimensionBuilders
import androidx.wear.tiles.ColorBuilders
import com.example.ai_watch.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

class MainTileService : TileService() {
    companion object {
        private const val RESOURCES_VERSION = "5"
    }

    private fun createButton(text: String, colorArgb: Int, action: ActionBuilders.Action): LayoutElementBuilders.LayoutElement {
        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.dp(38f))
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(
                        ModifiersBuilders.Clickable.Builder()
                            .setId("click_$text")
                            .setOnClick(action)
                            .build()
                    )
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(ColorBuilders.argb(colorArgb))
                            .setCorner(
                                ModifiersBuilders.Corner.Builder()
                                    .setRadius(DimensionBuilders.dp(19f))
                                    .build()
                            )
                            .build()
                    )
                    .setPadding(
                        ModifiersBuilders.Padding.Builder()
                            .setStart(DimensionBuilders.dp(12f))
                            .setEnd(DimensionBuilders.dp(12f))
                            .build()
                    )
                    .build()
            )
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(text)
                    .setFontStyle(
                        LayoutElementBuilders.FontStyle.Builder()
                            .setColor(ColorBuilders.argb(0xFFFFFFFF.toInt()))
                            .setSize(DimensionBuilders.sp(14f))
                            .build()
                    )
                    .build()
            )
            .build()
    }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val startChatAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setClassName("com.example.ai_watch.StartChatActivity")
                    .setPackageName(this.packageName)
                    .build()
            )
            .build()

        val assistantAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setClassName("com.example.ai_watch.AssistantActivity")
                    .setPackageName(this.packageName)
                    .build()
            )
            .build()

        val voiceModeAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setClassName("com.example.ai_watch.StartVoiceModeActivity")
                    .setPackageName(this.packageName)
                    .build()
            )
            .build()

        val columnLayout = LayoutElementBuilders.Column.Builder()
            .addContent(createButton("Чат", 0xFF00796B.toInt(), startChatAction))
            .addContent(
                LayoutElementBuilders.Spacer.Builder().setHeight(DimensionBuilders.dp(8f)).build()
            )
            .addContent(createButton("Голосовий ввід", 0xFF00B0FF.toInt(), assistantAction))
            .addContent(
                LayoutElementBuilders.Spacer.Builder().setHeight(DimensionBuilders.dp(8f)).build()
            )
            .addContent(createButton("Голосовий режим", 0xFFFF9800.toInt(), voiceModeAction))
            .build()

        val centeredLayout = LayoutElementBuilders.Box.Builder()
            .addContent(columnLayout)
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setPadding(
                        ModifiersBuilders.Padding.Builder()
                            .setAll(DimensionBuilders.dp(14f))
                            .build()
                    )
                    .build()
            )
            .build()

        val timeline = TimelineBuilders.Timeline.Builder()
            .addTimelineEntry(
                TimelineBuilders.TimelineEntry.Builder()
                    .setLayout(
                        LayoutElementBuilders.Layout.Builder()
                            .setRoot(centeredLayout)
                            .build()
                    )
                    .build()
            )
            .build()

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTimeline(timeline)
            .build()

        return Futures.immediateFuture(tile)
    }

    override fun onResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> {
        return Futures.immediateFuture(
            ResourceBuilders.Resources.Builder()
                .setVersion(RESOURCES_VERSION)
                .build()
        )
    }
}

package app.capgo.pdfviewer

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.widget.OverScroller
import io.legere.pdfiumandroid.PdfDocument
import kotlin.math.abs
import kotlin.math.max

internal data class PageLink(
    val pageIndex: Int,
    val bounds: RectF,
    val url: String,
)

class PdfViewerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onPageChanged(page: Int, pageCount: Int)
        fun onLinkTapped(url: String)
        fun onZoomChanged(scale: Float)
    }

    var listener: Listener? = null

    private var document: PdfDocument? = null
    private var pageCount = 0
    private var continuous = true
    private var currentPage = 0
    private var userScale = 1f
    private var fitScale = 1f
    private var scrollY = 0f
    private var pointWidths = FloatArray(0)
    private var pointHeights = FloatArray(0)
    private var pageWidths = FloatArray(0)
    private var pageHeights = FloatArray(0)
    private var pageOffsets = FloatArray(0)
    private var contentHeight = 0f
    private val bitmaps = mutableMapOf<Int, Bitmap>()
    private val links = mutableListOf<PageLink>()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val scroller = OverScroller(context)
    private val density = resources.displayMetrics.density

    private val scaleDetector = ScaleGestureDetector(
        context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                userScale = (userScale * detector.scaleFactor).coerceIn(0.5f, 4f)
                rebuildLayout()
                invalidate()
                emitZoom()
                return true
            }
        },
    )

    private val gestureDetector = GestureDetector(
        context,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean {
                scroller.forceFinished(true)
                return true
            }

            override fun onScroll(
                e1: MotionEvent?,
                e2: MotionEvent,
                distanceX: Float,
                distanceY: Float,
            ): Boolean {
                if (continuous) {
                    scrollY = (scrollY + distanceY).coerceIn(0f, maxScroll())
                    updateCurrentPageFromScroll()
                    invalidate()
                }
                return true
            }

            override fun onFling(
                e1: MotionEvent?,
                e2: MotionEvent,
                velocityX: Float,
                velocityY: Float,
            ): Boolean {
                if (!continuous) return false
                scroller.fling(
                    0,
                    scrollY.toInt(),
                    0,
                    -velocityY.toInt(),
                    0,
                    0,
                    0,
                    maxScroll().toInt(),
                )
                postInvalidateOnAnimation()
                return true
            }

            override fun onSingleTapUp(e: MotionEvent): Boolean {
                handleTap(e.x, e.y)
                return true
            }
        },
    )

    fun bind(document: PdfDocument, continuous: Boolean, initialPage: Int) {
        clearBitmaps()
        this.document = document
        this.continuous = continuous
        pageCount = document.getPageCount()
        currentPage = PdfViewerHelpers.pageIndex(initialPage, pageCount)
        userScale = 1f
        scrollY = 0f
        readPageMetrics()
        rebuildLayout()
        if (continuous) {
            scrollY = pageOffsets.getOrElse(currentPage) { 0f }
        }
        invalidate()
        emitPage()
    }

    fun goToPage(oneBased: Int) {
        currentPage = PdfViewerHelpers.pageIndex(oneBased, pageCount)
        if (continuous) {
            scrollY = pageOffsets.getOrElse(currentPage) { 0f }
        }
        clearBitmaps()
        renderVisiblePages()
        invalidate()
        emitPage()
    }

    fun setZoom(scale: Float) {
        userScale = scale.coerceIn(0.5f, 4f)
        rebuildLayout()
        invalidate()
        emitZoom()
    }

    fun currentZoom(): Float = userScale

    fun currentOneBasedPage(): Int = PdfViewerHelpers.oneBasedPage(currentPage, pageCount)

    fun totalPages(): Int = pageCount

    fun nextPage() {
        if (currentPage + 1 >= pageCount) return
        goToPage(PdfViewerHelpers.oneBasedPage(currentPage + 1, pageCount))
    }

    fun previousPage() {
        if (currentPage <= 0) return
        goToPage(PdfViewerHelpers.oneBasedPage(currentPage - 1, pageCount))
    }

    fun release() {
        clearBitmaps()
        document = null
        pageCount = 0
        links.clear()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (document != null && w > 0) {
            rebuildLayout()
        }
    }

    override fun computeScroll() {
        if (scroller.computeScrollOffset()) {
            scrollY = scroller.currY.toFloat()
            updateCurrentPageFromScroll()
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawColor(Color.BLACK)
        if (pageCount == 0 || width == 0) return

        if (continuous) {
            for (i in 0 until pageCount) {
                val top = pageOffsets[i] - scrollY
                if (top + pageHeights[i] >= 0 && top <= height) {
                    drawPage(canvas, i, top)
                }
            }
        } else {
            drawPage(canvas, currentPage, 0f)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        gestureDetector.onTouchEvent(event)
        return true
    }

    private fun drawPage(canvas: Canvas, index: Int, top: Float) {
        val bitmap = bitmaps[index] ?: run {
            renderPage(index)
            bitmaps[index]
        } ?: return
        val left = ((width - pageWidths[index]) / 2f).coerceAtLeast(0f)
        canvas.drawBitmap(bitmap, left, top, paint)
    }

    private fun readPageMetrics() {
        val doc = document ?: return
        pointWidths = FloatArray(pageCount)
        pointHeights = FloatArray(pageCount)
        links.clear()
        for (i in 0 until pageCount) {
            doc.openPage(i).use { page ->
                pointWidths[i] = page.getPageWidthPoint().toFloat()
                pointHeights[i] = page.getPageHeightPoint().toFloat()
                page.getPageLinks().forEach { link ->
                    val url = link.uri ?: return@forEach
                    links.add(PageLink(i, RectF(link.bounds), url))
                }
            }
        }
    }

    private fun rebuildLayout() {
        if (width <= 0 || pageCount == 0 || pointWidths.isEmpty()) return
        val maxPageWidth = pointWidths.maxOrNull() ?: return
        fitScale = (width.toFloat() / maxPageWidth).coerceAtLeast(0.01f)
        val scale = fitScale * userScale
        pageWidths = FloatArray(pageCount)
        pageHeights = FloatArray(pageCount)
        pageOffsets = FloatArray(pageCount)
        var offset = 0f
        for (i in 0 until pageCount) {
            pageWidths[i] = pointWidths[i] * scale
            pageHeights[i] = pointHeights[i] * scale
            pageOffsets[i] = offset
            offset += pageHeights[i] + pageGap()
        }
        contentHeight = offset
        scrollY = scrollY.coerceIn(0f, maxScroll())
        clearBitmaps()
        renderVisiblePages()
    }

    private fun renderVisiblePages() {
        if (document == null || width <= 0 || pageCount == 0) return
        val targets = if (continuous) {
            (0 until pageCount).filter { i ->
                val top = pageOffsets[i] - scrollY
                top + pageHeights[i] >= -height && top <= height * 2
            }
        } else {
            listOf(currentPage)
        }
        bitmaps.keys.filter { it !in targets }.forEach { index ->
            bitmaps.remove(index)?.recycle()
        }
        targets.forEach { renderPage(it) }
    }

    private fun renderPage(index: Int) {
        if (bitmaps.containsKey(index)) return
        val doc = document ?: return
        val w = max(1, pageWidths[index].toInt())
        val h = max(1, pageHeights[index].toInt())
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        doc.openPage(index).use { page ->
            page.renderPageBitmap(bitmap, 0, 0, w, h, renderAnnot = true)
        }
        bitmaps[index] = bitmap
    }

    private fun handleTap(x: Float, y: Float) {
        val scale = fitScale * userScale
        val pageIndex = if (continuous) {
            pageOffsets.indices.firstOrNull { i ->
                val top = pageOffsets[i] - scrollY
                y >= top && y <= top + pageHeights[i]
            } ?: return
        } else {
            currentPage
        }
        val top = if (continuous) pageOffsets[pageIndex] - scrollY else 0f
        val left = ((width - pageWidths[pageIndex]) / 2f).coerceAtLeast(0f)
        val localX = (x - left) / scale
        val localY = pointHeights[pageIndex] - ((y - top) / scale)

        links.filter { it.pageIndex == pageIndex }.forEach { link ->
            if (link.bounds.contains(localX, localY)) {
                listener?.onLinkTapped(link.url)
                return
            }
        }
    }

    private fun updateCurrentPageFromScroll() {
        if (!continuous || pageCount == 0) return
        val center = scrollY + height / 2f
        var best = 0
        var bestDist = Float.MAX_VALUE
        for (i in 0 until pageCount) {
            val mid = pageOffsets[i] + pageHeights[i] / 2f
            val dist = abs(mid - center)
            if (dist < bestDist) {
                bestDist = dist
                best = i
            }
        }
        if (best != currentPage) {
            currentPage = best
            emitPage()
        }
        renderVisiblePages()
    }

    private fun emitPage() {
        listener?.onPageChanged(
            PdfViewerHelpers.oneBasedPage(currentPage, pageCount),
            pageCount,
        )
    }

    private fun emitZoom() {
        listener?.onZoomChanged(userScale)
    }

    private fun clearBitmaps() {
        bitmaps.values.forEach { it.recycle() }
        bitmaps.clear()
    }

    private fun maxScroll(): Float = max(0f, contentHeight - height)

    private fun pageGap(): Float = 8f * density
}

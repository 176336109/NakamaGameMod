package logger

import (
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// GinLogger is a middleware that logs HTTP requests using zap
func GinLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		if len(c.Errors) > 0 {
			for _, e := range c.Errors.Errors() {
				Log.Error(e)
			}
		} else {
			Log.Info(path,
				zap.Int("status", status),
				zap.String("method", c.Request.Method),
				zap.String("path", path),
				zap.String("query", query),
				zap.String("ip", c.ClientIP()),
				zap.String("user-agent", c.Request.UserAgent()),
				zap.Duration("latency", latency),
			)
		}
	}
}

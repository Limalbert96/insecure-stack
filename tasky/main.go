package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
	controller "github.com/jeffthorne/tasky/controllers"
	"github.com/joho/godotenv"
)

func index(c *gin.Context) {
	c.HTML(http.StatusOK, "login.html", nil)
}

func main() {
	godotenv.Overload()

	// Set Gin to release mode
	gin.SetMode(gin.ReleaseMode)

	router := gin.Default()
	router.LoadHTMLGlob("assets/*.html")
	router.Static("/assets", "./assets")

	// Handle both GET and HEAD requests for root path
	router.GET("/", index)
	router.HEAD("/", index)

	// Handle API routes
	router.GET("/todos/:userid", controller.GetTodos)
	router.HEAD("/todos/:userid", controller.GetTodos)
	router.GET("/todo/:id", controller.GetTodo)
	router.HEAD("/todo/:id", controller.GetTodo)
	router.POST("/todo/:userid", controller.AddTodo)
	router.DELETE("/todo/:userid/:id", controller.DeleteTodo)
	router.DELETE("/todos/:userid", controller.ClearAll)
	router.PUT("/todo", controller.UpdateTodo)

	router.POST("/signup", controller.SignUp)
	router.POST("/login", controller.Login)
	router.GET("/todo", controller.Todo)

	router.Run(":8080")

}

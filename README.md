To run any task:

Enter the task folder:

`cd task1` or `cd task2`

Create image from dockerfile

`docker build -t <image-name-here> ./`

Run Container from image

`docker run --name <container-name-here>  -p 8000:8000 <image-name-here>`

-include .env

IMAGE ?= $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-build docker-push k8s-apply k8s-delete

docker-build:
	docker build -t $(IMAGE) -f docker/Dockerfile .

docker-push:
	docker push $(IMAGE)

k8s-apply:
	kubectl apply -f k8s/pvc.yaml
	sed 's#ghcr.io/your-org/mineru-nibi:latest#$(IMAGE)#' k8s/job-mineru.yaml | kubectl apply -f -

k8s-delete:
	kubectl delete -f k8s/job-mineru.yaml || true
	kubectl delete -f k8s/pvc.yaml || true

